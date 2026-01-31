# HTTP Client Bootstrap - Connection setup and ALPN-based handler creation
# Port of aws-c-http/source/connection.c (client connect flow)

using AwsIO: ClientBootstrap, SocketOptions, ChannelSlot, Channel,
             client_bootstrap_connect!, channel_slot_new!,
             channel_slot_set_handler!, channel_slot_insert_end!,
             ByteBuffer, byte_buffer_as_string

# ─── http_connection_get_channel dispatches ───

http_connection_get_channel(conn::H1Connection) = conn.slot !== nothing ? conn.slot.channel : nothing
http_connection_get_channel(conn::H2Connection) = conn.slot !== nothing ? conn.slot.channel : nothing

# ─── Connection channel handler creation ───

"""
    http_connection_new_channel_handler(; is_server, version, ...) -> AbstractChannelHandler

Create the appropriate HTTP connection handler (H1 or H2) based on the negotiated version.
This is the factory function called during ALPN negotiation or direct connection setup.
"""
function http_connection_new_channel_handler(;
    is_server::Bool,
    version::HttpVersion.T,
    manual_window_management::Bool = false,
    initial_window_size::Csize_t = Csize_t(typemax(Csize_t)),
    user_data = nothing,
    on_shutdown = nothing,
    on_channel_handler_installed = nothing,
    proxy_request_transform = nothing,
    response_first_byte_timeout_ms::UInt64 = UInt64(0),
    read_buffer_capacity::Csize_t = Csize_t(0),
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
                on_channel_handler_installed,
                proxy_request_transform,
                response_first_byte_timeout_ms,
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
    http_client_connect(options::HttpClientConnectionOptions) -> Union{Nothing, ErrorResult}

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

    # Determine the HTTP version for non-ALPN case
    default_version = if options.prior_knowledge_http2
        HttpVersion.HTTP_2
    else
        HttpVersion.HTTP_1_1
    end

    # Define the ALPN protocol negotiation callback.
    # Called by channel bootstrap when TLS ALPN completes.
    # Must return an AbstractChannelHandler to install in the channel.
    on_protocol_negotiated = if options.tls_connection_options !== nothing
        (new_slot, protocol::ByteBuffer, ud) -> begin
            protocol_str = byte_buffer_as_string(protocol)
            version = http_alpn_map_get(http_bootstrap.alpn_map, protocol_str)
            if version == HttpVersion.UNKNOWN
                version = HttpVersion.HTTP_1_1
            end

            handler = http_connection_new_channel_handler(;
                is_server = false,
                version,
                manual_window_management = options.manual_window_management,
                initial_window_size = options.initial_window_size,
                user_data = options.user_data,
                on_shutdown = options.on_shutdown !== nothing ?
                    (conn, err, ud2) -> options.on_shutdown(conn, err, options.user_data) : nothing,
                response_first_byte_timeout_ms = options.response_first_byte_timeout_ms,
                read_buffer_capacity = options.http1_options.read_buffer_capacity,
            )
            http_bootstrap.connection = handler
            return handler
        end
    else
        nothing
    end

    # on_setup: fires when the channel is fully set up (after TLS + ALPN).
    on_setup = (bootstrap, error_code, channel, ud) -> begin
        if error_code != AwsIO.OP_SUCCESS
            if options.on_setup !== nothing
                options.on_setup(nothing, error_code, options.user_data)
            end
            return nothing
        end

        # If no ALPN (no TLS or prior knowledge), create the handler now
        if http_bootstrap.connection === nothing
            handler = http_connection_new_channel_handler(;
                is_server = false,
                version = default_version,
                manual_window_management = options.manual_window_management,
                initial_window_size = options.initial_window_size,
                user_data = options.user_data,
                on_shutdown = options.on_shutdown !== nothing ?
                    (conn, err, ud2) -> options.on_shutdown(conn, err, options.user_data) : nothing,
                response_first_byte_timeout_ms = options.response_first_byte_timeout_ms,
                read_buffer_capacity = options.http1_options.read_buffer_capacity,
            )
            http_bootstrap.connection = handler

            # Install the handler in the channel
            slot = channel_slot_new!(channel)
            channel_slot_insert_end!(channel, slot)
            channel_slot_set_handler!(slot, handler)
        end

        conn = http_bootstrap.connection
        if conn !== nothing && hasproperty(conn, :remote_endpoint)
            conn.remote_endpoint = "$(options.host_name):$(options.port)"
        end

        if options.on_setup !== nothing
            options.on_setup(conn, AwsIO.OP_SUCCESS, options.user_data)
        end
        return nothing
    end

    # on_shutdown: fires when the channel shuts down.
    on_shutdown_cb = (bootstrap, error_code, channel, ud) -> begin
        conn = http_bootstrap.connection
        if conn !== nothing && options.on_shutdown !== nothing
            options.on_shutdown(conn, error_code, options.user_data)
        end
        return nothing
    end

    # Initiate connection via AwsIO's ClientBootstrap
    result = client_bootstrap_connect!(
        options.bootstrap,
        options.host_name,
        options.port;
        socket_options = options.socket_options !== nothing ? options.socket_options : AwsIO.SocketOptions(),
        tls_connection_options = options.tls_connection_options,
        on_protocol_negotiated = on_protocol_negotiated,
        on_setup = on_setup,
        on_shutdown = on_shutdown_cb,
        user_data = http_bootstrap,
        requested_event_loop = options.requested_event_loop,
    )

    return result
end
