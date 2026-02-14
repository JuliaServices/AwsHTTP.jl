# HTTP Client Bootstrap - Connection setup and ALPN-based handler creation
# Port of aws-c-http/source/connection.c (client connect flow)

# ─── http_connection_get_pipeline dispatches ───

http_connection_get_pipeline(conn::H1Connection) = conn.pipeline
http_connection_get_pipeline(conn::H2Connection) = conn.pipeline

# ─── Connection handler creation ───

"""
    http_connection_new_handler(; is_server, version, ...) -> handler

Create the appropriate HTTP connection handler (H1 or H2) based on the negotiated version.
This is the factory function called during ALPN negotiation or direct connection setup.
"""
function http_connection_new_handler(;
    is_server::Bool,
    version::HttpVersion.T,
    manual_window_management::Bool = false,
    initial_window_size::Csize_t = Csize_t(typemax(Csize_t)),
    user_data = nothing,
    on_shutdown = nothing,
    proxy_request_transform = nothing,
    response_first_byte_timeout_ms::UInt64 = UInt64(0),
    read_buffer_capacity::Csize_t = Csize_t(0),
    h2c_upgrade::Bool = false,
)
    if version == HttpVersion.HTTP_1_1
        if is_server
            return h1_connection_new_server(;
                manual_window_management,
                initial_window_size,
                read_buffer_capacity,
                user_data,
                on_shutdown,
            )
        else
            return h1_connection_new_client(;
                manual_window_management,
                initial_window_size,
                read_buffer_capacity,
                user_data,
                on_shutdown,
                proxy_request_transform,
                response_first_byte_timeout_ms,
                h2c_upgrade,
            )
        end
    elseif version == HttpVersion.HTTP_2
        return h2_connection_new(;
            is_client = !is_server,
            user_data,
            manual_window_management,
            initial_window_size = UInt32(min(initial_window_size, typemax(UInt32))),
            on_shutdown,
        )
    else
        return nothing
    end
end

# ─── Client connection bootstrap ───

# Internal state for tracking an in-progress client connection setup.
# Mirrors aws-c-http's _HttpClientBootstrap.
mutable struct _HttpClientBootstrap
    options::HttpClientConnectionOptions
    alpn_map::HttpAlpnMap
    connection::Any  # H1Connection or H2Connection, set during setup
end

"""
    http_client_connect(options::HttpClientConnectionOptions) -> Nothing

Initiate an asynchronous HTTP client connection. When the connection is established,
`options.on_setup` is called with the connection object. On failure, `options.on_setup`
is called with `nothing` and an error code.

The ALPN protocol negotiated during TLS determines whether an HTTP/1.1 or HTTP/2
connection handler is created. If `prior_knowledge_http2` is set, HTTP/2 is used
without ALPN negotiation.
"""
function http_client_connect(options::HttpClientConnectionOptions)
    # Build the ALPN map
    alpn_map = if options.alpn_string_map !== nothing
        http_alpn_map_init_copy(options.alpn_string_map)
    else
        http_alpn_map_init()
    end

    http_bootstrap = _HttpClientBootstrap(options, alpn_map, nothing)

    # on_setup: fires when the pipeline is fully set up (after TLS + ALPN).
    on_setup = (bootstrap, error_code, pipeline, ud) -> begin
        Reseau.logf(Reseau.LogLevel.DEBUG, LS_HTTP_CONNECTION, string("http_client_connect on_setup wrapper invoked err=", error_code))
        if error_code != Reseau.OP_SUCCESS
            if options.on_setup !== nothing
                _dispatch_user_callback(options.on_setup, nothing, error_code, options.user_data; label = "on_setup")
            end
            return nothing
        end

        local version
        try
            version = _http_select_version_from_pipeline(
                pipeline,
                options.tls_connection_options !== nothing,
                options.prior_knowledge_http2,
                http_bootstrap.alpn_map,
            )
        catch e
            err = e isa Reseau.ReseauError ? e.code : Reseau.ERROR_UNKNOWN
            Sockets.pipeline_shutdown!(pipeline, err)
            if options.on_setup !== nothing
                _dispatch_user_callback(options.on_setup, nothing, err, options.user_data; label = "on_setup")
            end
            return nothing
        end
        if version == HttpVersion.UNKNOWN
            err = ERROR_HTTP_UNSUPPORTED_PROTOCOL
            Sockets.pipeline_shutdown!(pipeline, err)
            if options.on_setup !== nothing
                _dispatch_user_callback(options.on_setup, nothing, err, options.user_data; label = "on_setup")
            end
            return nothing
        end
        handler = http_connection_new_handler(;
            is_server = false,
            version,
            manual_window_management = options.manual_window_management,
            initial_window_size = options.initial_window_size,
            user_data = options.user_data,
            on_shutdown = options.on_shutdown !== nothing ?
                (conn, err, ud2) -> _dispatch_user_callback(options.on_shutdown, conn, err, options.user_data; label = "on_shutdown") : nothing,
            response_first_byte_timeout_ms = options.response_first_byte_timeout_ms,
            read_buffer_capacity = options.http1_options.read_buffer_capacity,
            h2c_upgrade = options.h2c_upgrade,
        )
        if handler === nothing
            err = ERROR_HTTP_UNSUPPORTED_PROTOCOL
            Sockets.pipeline_shutdown!(pipeline, err)
            if options.on_setup !== nothing
                _dispatch_user_callback(options.on_setup, nothing, err, options.user_data; label = "on_setup")
            end
            return nothing
        end
        http_bootstrap.connection = handler

        # Install the HTTP handler as middleware on the pipeline
        socket = pipeline.socket isa Sockets.Socket ? pipeline.socket::Sockets.Socket : nothing
        if handler isa H1Connection
            h1_connection_install!(handler, pipeline, socket)
        elseif handler isa H2Connection
            h2_connection_install!(handler, pipeline, socket)
        end

        conn = http_bootstrap.connection
        if conn !== nothing && hasproperty(conn, :remote_endpoint)
            conn.remote_endpoint = "$(options.host_name):$(options.port)"
        end

        # Trigger initial read
        if socket !== nothing
            if Sockets.pipeline_thread_is_callers_thread(pipeline)
                Sockets.pipeline_trigger_read(socket)
            else
                task = Sockets.ChannelTask(Reseau.EventCallable(status -> begin
                    Reseau.TaskStatus.T(status) == Reseau.TaskStatus.RUN_READY || return nothing
                    Sockets.pipeline_trigger_read(socket)
                    return nothing
                end), "http_client_trigger_read")
                Sockets.pipeline_schedule_task_now!(pipeline, task)
            end
        end

        if options.on_setup !== nothing
            Reseau.logf(Reseau.LogLevel.DEBUG, LS_HTTP_CONNECTION, "http_client_connect invoking user on_setup")
            _dispatch_user_callback(options.on_setup, conn, Reseau.OP_SUCCESS, options.user_data; label = "on_setup")
        else
            Reseau.logf(Reseau.LogLevel.DEBUG, LS_HTTP_CONNECTION, "http_client_connect user on_setup is nothing")
        end
        return nothing
    end

    # on_shutdown: fires when the pipeline shuts down.
    on_shutdown_cb = (bootstrap, error_code, pipeline, ud) -> begin
        conn = http_bootstrap.connection
        if conn !== nothing && options.on_shutdown !== nothing
            _dispatch_user_callback(options.on_shutdown, conn, error_code, options.user_data; label = "on_shutdown")
        end
        return nothing
    end

    # Initiate connection via Reseau's ClientBootstrap
    result = Sockets.client_bootstrap_connect!(
        options.bootstrap,
        options.host_name,
        options.port;
        socket_options = options.socket_options !== nothing ? options.socket_options : Sockets.SocketOptions(),
        tls_connection_options = options.tls_connection_options,
        on_protocol_negotiated = nothing,
        on_setup = on_setup,
        on_shutdown = on_shutdown_cb,
        user_data = http_bootstrap,
        requested_event_loop = options.requested_event_loop,
    )

    return result
end
