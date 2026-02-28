# HTTP Client Bootstrap - Connection setup and ALPN-based handler creation
# Port of aws-c-http/source/connection.c (client connect flow)

# ─── http_connection_get_channel dispatches ───

http_connection_get_channel(conn::H1Connection) = conn.slot !== nothing ? conn.slot.channel : nothing
http_connection_get_channel(conn::H2Connection) = conn.slot !== nothing ? conn.slot.channel : nothing

# ─── Connection channel handler creation ───

"""
    http_connection_new_channel_handler(; is_server, version, ...) -> Union{H1Connection, H2Connection, Nothing}

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
                on_channel_handler_installed,
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
    negotiated_protocol::Union{String, Nothing}
end

_HttpClientBootstrap(options::HttpClientConnectionOptions, alpn_map::HttpAlpnMap, connection) =
    _HttpClientBootstrap(options, alpn_map, connection, nothing)

const DEFAULT_HTTP_CLIENT_EVENT_LOOP_GROUP = Base.ScopedValues.ScopedValue{Any}()

get_client_event_loop_group() =
    isassigned(DEFAULT_HTTP_CLIENT_EVENT_LOOP_GROUP) ? DEFAULT_HTTP_CLIENT_EVENT_LOOP_GROUP[] : EventLoops.get_event_loop_group()

function with_client_bootstrap(f::Function, event_loop_group)
    return Base.ScopedValues.with(f, DEFAULT_HTTP_CLIENT_EVENT_LOOP_GROUP => event_loop_group)
end

struct _HttpClientConnectPlan
    connect_host::String
    connect_port::UInt32
    use_tunnel::Bool
end

function _http_client_connect_plan(options::HttpClientConnectionOptions)::_HttpClientConnectPlan
    proxy_options = options.proxy_options
    if !(proxy_options isa HttpProxyOptions)
        return _HttpClientConnectPlan(options.host_name, options.port, false)
    end
    if !isempty(proxy_options.no_proxy_hosts) && http_host_matches_no_proxy(options.host_name, proxy_options.no_proxy_hosts)
        return _HttpClientConnectPlan(options.host_name, options.port, false)
    end
    if isempty(proxy_options.host) || proxy_options.port == 0
        return _HttpClientConnectPlan(options.host_name, options.port, false)
    end
    proxy_connection_type = http_proxy_effective_connection_type(proxy_options, options.tls_connection_options)
    if proxy_connection_type == HttpProxyConnectionType.HTTP_FORWARD ||
       proxy_connection_type == HttpProxyConnectionType.HTTP_TUNNEL
        return _HttpClientConnectPlan(
            proxy_options.host,
            proxy_options.port,
            proxy_connection_type == HttpProxyConnectionType.HTTP_TUNNEL,
        )
    end
    return _HttpClientConnectPlan(options.host_name, options.port, false)
end

function _http_client_build_proxy_request_transform(options::HttpClientConnectionOptions)
    proxy_options = options.proxy_options
    !(proxy_options isa HttpProxyOptions) && return nothing
    if !isempty(proxy_options.no_proxy_hosts) && http_host_matches_no_proxy(options.host_name, proxy_options.no_proxy_hosts)
        return nothing
    end
    if isempty(proxy_options.host) || proxy_options.port == UInt32(0)
        return nothing
    end
    proxy_connection_type = http_proxy_effective_connection_type(proxy_options, options.tls_connection_options)
    if proxy_connection_type != HttpProxyConnectionType.HTTP_FORWARD
        return nothing
    end
    strategy = http_proxy_strategy_from_options(proxy_options, options.tls_connection_options)
    strategy === nothing && return nothing
    negotiator = http_proxy_strategy_create_negotiator(strategy)
    negotiator === nothing && return nothing
    if negotiator.is_tunnelling || negotiator.forwarding_vtable === nothing ||
       negotiator.forwarding_vtable.forward_request_transform === nothing
        return nothing
    end
    target_host = options.host_name
    target_port = options.port
    return (request, user_data) -> begin
        http_rewrite_uri_for_proxy_request(request, target_host, target_port) == OP_SUCCESS || return OP_ERR
        return negotiator.forwarding_vtable.forward_request_transform(negotiator, request)
    end
end

function _http_client_connect_target(options::HttpClientConnectionOptions)::Tuple{String, UInt32}
    plan = _http_client_connect_plan(options)
    return (plan.connect_host, plan.connect_port)
end

function _http_client_bootstrap_fail_setup!(
        options::HttpClientConnectionOptions,
        setup_reported::Base.RefValue{Bool},
        channel,
        error_code::Int,
    )::Nothing
    if setup_reported[]
        return nothing
    end
    setup_reported[] = true
    channel !== nothing && Sockets.channel_shutdown!(channel, error_code)
    if options.on_setup !== nothing
        _dispatch_user_callback(options.on_setup, nothing, error_code, options.user_data; label = "on_setup")
    end
    return nothing
end

function _http_client_bootstrap_trigger_read!(channel)::Nothing
    channel === nothing && return nothing
    if Sockets.channel_thread_is_callers_thread(channel)
        Sockets.channel_trigger_read(channel)
    else
        task = Sockets.ChannelTask(Reseau.EventCallable(status -> begin
            Reseau.TaskStatus.T(status) == Reseau.TaskStatus.RUN_READY || return nothing
            Sockets.channel_trigger_read(channel)
            return nothing
        end), "http_client_trigger_read")
        Sockets.channel_schedule_task_now!(channel, task)
    end
    return nothing
end

function _http_client_bootstrap_schedule_channel_callback!(
        channel,
        label::AbstractString,
        f::Function,
    )::Nothing
    if Sockets.channel_thread_is_callers_thread(channel)
        f()
        return nothing
    end
    task = Sockets.ChannelTask(Reseau.EventCallable(status -> begin
        Reseau.TaskStatus.T(status) == Reseau.TaskStatus.RUN_READY || return nothing
        f()
        return nothing
    end), String(label))
    Sockets.channel_schedule_task_now!(channel, task)
    return nothing
end

function _http_client_bootstrap_install_handler!(
        http_bootstrap::_HttpClientBootstrap,
        channel,
        is_using_tls::Bool,
    )::Int
    if http_bootstrap.connection !== nothing
        return OP_SUCCESS
    end

    options = http_bootstrap.options
    http_bootstrap.negotiated_protocol = Sockets.negotiated_protocol(channel)
    slot = Sockets.channel_slot_new!(channel)
    Sockets.channel_slot_insert_end!(channel, slot)

    local version
    try
        version = _http_select_version(
            channel,
            is_using_tls,
            options.prior_knowledge_http2,
            http_bootstrap.alpn_map,
            http_bootstrap.negotiated_protocol,
        )
    catch e
        return e isa Reseau.ReseauError ? e.code : Reseau.ERROR_UNKNOWN
    end

    if version == HttpVersion.UNKNOWN
        return ERROR_HTTP_UNSUPPORTED_PROTOCOL
    end

    proxy_request_transform = _http_client_build_proxy_request_transform(options)

    handler = http_connection_new_channel_handler(;
        is_server = false,
        version,
        manual_window_management = options.manual_window_management,
        initial_window_size = options.initial_window_size,
        user_data = options.user_data,
        on_shutdown = options.on_shutdown !== nothing ?
            (conn, err, ud2) -> _dispatch_user_callback(options.on_shutdown, conn, err, options.user_data; label = "on_shutdown") : nothing,
        proxy_request_transform = proxy_request_transform,
        response_first_byte_timeout_ms = options.response_first_byte_timeout_ms,
        read_buffer_capacity = options.http1_options.read_buffer_capacity,
        h2c_upgrade = options.h2c_upgrade,
    )
    handler === nothing && return ERROR_HTTP_UNSUPPORTED_PROTOCOL

    http_bootstrap.connection = handler
    Sockets.channel_slot_set_handler!(slot, handler)
    return OP_SUCCESS
end

function _http_client_bootstrap_report_success!(
        http_bootstrap::_HttpClientBootstrap,
        setup_reported::Base.RefValue{Bool},
        channel,
    )::Nothing
    setup_reported[] && return nothing
    setup_reported[] = true
    options = http_bootstrap.options
    conn = http_bootstrap.connection
    if conn !== nothing && hasproperty(conn, :remote_endpoint)
        conn.remote_endpoint = "$(options.host_name):$(options.port)"
    end
    _http_client_bootstrap_trigger_read!(channel)
    if options.on_setup !== nothing
        _dispatch_user_callback(options.on_setup, conn, Reseau.OP_SUCCESS, options.user_data; label = "on_setup")
    end
    return nothing
end

function _h1_connection_flush_outgoing!(conn::H1Connection)::Int
    slot = conn.slot
    slot === nothing && return raise_error(ERROR_INVALID_STATE)
    output = UInt8[]
    while true
        status, chunk = h1_connection_encode_outgoing!(conn)
        status != OP_SUCCESS && return OP_ERR
        isempty(chunk) && break
        append!(output, chunk)
    end
    isempty(output) && return OP_SUCCESS
    msg = Sockets.IoMessage(length(output))
    buf = msg.message_data
    @inbounds for i in 1:length(output)
        buf.mem[i] = output[i]
    end
    buf.len = Csize_t(length(output))
    Sockets.channel_slot_send_message(slot, msg, Sockets.ChannelDirection.WRITE)
    return OP_SUCCESS
end

function _http_proxy_build_connect_request(options::HttpClientConnectionOptions)::Union{HttpMessage, Nothing}
    request = http_message_new_request()
    request === nothing && return nothing
    target = "$(options.host_name):$(options.port)"
    http_message_set_request_method(request, "CONNECT") != OP_SUCCESS && return nothing
    http_message_set_request_path(request, target) != OP_SUCCESS && return nothing
    headers = http_message_get_headers(request)
    http_headers_add(headers, "Host", target) != OP_SUCCESS && return nothing
    http_headers_add(headers, "Proxy-Connection", "Keep-Alive") != OP_SUCCESS && return nothing
    return request
end

function _http_proxy_prepare_connect_request(
        options::HttpClientConnectionOptions,
    )
    request = _http_proxy_build_connect_request(options)
    request === nothing && return (nothing, nothing, OP_ERR)
    proxy_options = options.proxy_options
    !(proxy_options isa HttpProxyOptions) && return (request, nothing, OP_SUCCESS)
    strategy = http_proxy_strategy_from_options(proxy_options, options.tls_connection_options)
    strategy === nothing && return (request, nothing, OP_SUCCESS)
    negotiator = http_proxy_strategy_create_negotiator(strategy)
    negotiator === nothing && return (request, nothing, OP_SUCCESS)
    if !negotiator.is_tunnelling || negotiator.tunnelling_vtable === nothing
        return (request, negotiator, OP_SUCCESS)
    end
    transform = negotiator.tunnelling_vtable.connect_request_transform
    transform === nothing && return (request, negotiator, OP_SUCCESS)

    forwarded_request = Ref{Any}(nothing)
    done_error = Ref{Int}(OP_SUCCESS)
    callback_kind = Ref(:none)
    on_done = (args...) -> begin
        callback_kind[] = :done
        if !isempty(args) && args[1] isa Integer
            done_error[] = Int(args[1])
        else
            done_error[] = ERROR_HTTP_PROXY_CONNECT_FAILED
        end
        return nothing
    end
    on_forward = (message, args...) -> begin
        callback_kind[] = :forward
        forwarded_request[] = message
        return nothing
    end
    try
        transform(negotiator, request, on_done, on_forward, nothing)
    catch
        return (nothing, negotiator, OP_ERR)
    end
    if callback_kind[] == :done
        err = done_error[]
        err == OP_SUCCESS && (err = ERROR_HTTP_PROXY_CONNECT_FAILED)
        return (nothing, negotiator, err)
    end
    if callback_kind[] == :forward
        return forwarded_request[] isa HttpMessage ?
            (forwarded_request[]::HttpMessage, negotiator, OP_SUCCESS) :
            (nothing, negotiator, OP_ERR)
    end
    return (nothing, negotiator, ERROR_HTTP_PROXY_CONNECT_FAILED)
end

function _http_proxy_connect_error_from_status(
        status_code::Int,
        negotiator,
    )::Int
    status_code == 200 && return OP_SUCCESS
    if status_code == 407 && negotiator !== nothing
        directive = http_proxy_negotiator_get_retry_directive(negotiator)
        if directive == HttpProxyNegotiationRetryDirective.NEW_CONNECTION ||
           directive == HttpProxyNegotiationRetryDirective.CURRENT_CONNECTION
            return ERROR_HTTP_PROXY_CONNECT_FAILED_RETRYABLE
        end
    end
    return ERROR_HTTP_PROXY_CONNECT_FAILED
end

function _http_client_bootstrap_start_origin_tls!(
        http_bootstrap::_HttpClientBootstrap,
        channel,
        on_ready::Function,
        on_error::Function,
    )::Int
    tls_options = http_bootstrap.options.tls_connection_options
    if tls_options === nothing
        on_ready()
        return OP_SUCCESS
    end
    socket_slot = Sockets.channel_first_slot(channel)
    socket_slot === nothing && return raise_error(ERROR_INVALID_STATE)
    tls_future = EventLoops.Future{Cint}()
    tls_options.tls_negotiation_result = tls_future
    setup_tls! = () -> begin
        try
            Sockets.channel_setup_client_tls(socket_slot, tls_options)
        catch e
            err = e isa Reseau.ReseauError ? e.code : Reseau.ERROR_UNKNOWN
            on_error(err)
            return nothing
        end
        errormonitor(Threads.@spawn begin
            err = Int(wait(tls_future))
            _http_client_bootstrap_schedule_channel_callback!(channel, "http_client_tunnel_tls_result") do
                err == OP_SUCCESS ? on_ready() : on_error(err)
            end
            return nothing
        end)
        return nothing
    end
    _http_client_bootstrap_schedule_channel_callback!(channel, "http_client_tunnel_tls_setup", setup_tls!)
    return OP_SUCCESS
end

function _http_client_bootstrap_start_proxy_tunnel!(
        http_bootstrap::_HttpClientBootstrap,
        channel,
        on_ready::Function,
        on_error::Function,
    )::Int
    request, negotiator, prep_status = _http_proxy_prepare_connect_request(http_bootstrap.options)
    prep_status != OP_SUCCESS && return prep_status
    request === nothing && return raise_error(ERROR_INVALID_STATE)

    slot = Sockets.channel_slot_new!(channel)
    Sockets.channel_slot_insert_end!(channel, slot)
    proxy_conn = h1_connection_new_client()
    Sockets.channel_slot_set_handler!(slot, proxy_conn)

    status_code_ref = Ref(0)
    complete_once = Ref(false)
    request_options = HttpMakeRequestOptions(
        request = request,
        on_response_headers = (stream, block, headers, ud) -> begin
            if negotiator !== nothing && negotiator.is_tunnelling && negotiator.tunnelling_vtable !== nothing
                cb = negotiator.tunnelling_vtable.on_incoming_headers
                cb !== nothing && return cb(negotiator, block, headers)
            end
            return OP_SUCCESS
        end,
        on_response_header_block_done = (stream, block, ud) -> begin
            if block == HttpHeaderBlock.MAIN
                status_code_ref[] = http_stream_get_incoming_response_status(stream)
                if negotiator !== nothing && negotiator.is_tunnelling && negotiator.tunnelling_vtable !== nothing
                    cb = negotiator.tunnelling_vtable.on_status
                    cb !== nothing && return cb(negotiator, status_code_ref[])
                end
            end
            return OP_SUCCESS
        end,
        on_response_body = (stream, data, ud) -> begin
            if negotiator !== nothing && negotiator.is_tunnelling && negotiator.tunnelling_vtable !== nothing
                cb = negotiator.tunnelling_vtable.on_incoming_body
                cb !== nothing && return cb(negotiator, data)
            end
            return OP_SUCCESS
        end,
        on_complete = (stream, error_code, ud) -> begin
            complete_once[] && return nothing
            complete_once[] = true
            _http_client_bootstrap_schedule_channel_callback!(channel, "http_client_proxy_connect_complete") do
                Sockets.channel_slot_remove!(slot)
                if error_code != OP_SUCCESS
                    on_error(error_code)
                    return nothing
                end
                proxy_err = _http_proxy_connect_error_from_status(status_code_ref[], negotiator)
                proxy_err != OP_SUCCESS && return on_error(proxy_err)
                return on_ready()
            end
            return nothing
        end,
    )
    stream = http_connection_make_request(proxy_conn, request_options)
    stream === nothing && return OP_ERR
    h1_stream_activate!(stream) != OP_SUCCESS && return OP_ERR
    return _h1_connection_flush_outgoing!(proxy_conn)
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
    event_loop_group = options.bootstrap === nothing ? get_client_event_loop_group() : options.bootstrap
    if !(event_loop_group isa EventLoops.EventLoopGroup)
        event_loop_group = EventLoops.get_event_loop_group()
    end

    # Build the ALPN map
    alpn_map = if options.alpn_string_map !== nothing
        http_alpn_map_init_copy(options.alpn_string_map)
    else
        http_alpn_map_init()
    end

    http_bootstrap = _HttpClientBootstrap(options, alpn_map, nothing, nothing)
    connect_plan = _http_client_connect_plan(options)
    setup_reported = Ref(false)
    tunnel_started = Ref(false)

    # on_setup: fires when the channel is fully set up (after TLS + ALPN).
    on_setup = (error_code, channel) -> begin
        Reseau.logf(Reseau.LogLevel.DEBUG, LS_HTTP_CONNECTION, "http_client_connect on_setup wrapper invoked err=$(error_code)")
        if error_code != Reseau.OP_SUCCESS
            _http_client_bootstrap_fail_setup!(options, setup_reported, channel, error_code)
            return nothing
        end

        if http_bootstrap.connection === nothing
            if connect_plan.use_tunnel && !tunnel_started[]
                tunnel_started[] = true
                start_status = _http_client_bootstrap_start_proxy_tunnel!(
                    http_bootstrap,
                    channel,
                    () -> begin
                        tls_status = _http_client_bootstrap_start_origin_tls!(
                            http_bootstrap,
                            channel,
                            () -> begin
                                err = _http_client_bootstrap_install_handler!(
                                    http_bootstrap,
                                    channel,
                                    options.tls_connection_options !== nothing,
                                )
                                if err != OP_SUCCESS
                                    _http_client_bootstrap_fail_setup!(options, setup_reported, channel, err)
                                    return nothing
                                end
                                _http_client_bootstrap_report_success!(http_bootstrap, setup_reported, channel)
                                return nothing
                            end,
                            err -> _http_client_bootstrap_fail_setup!(options, setup_reported, channel, err),
                        )
                        tls_status != OP_SUCCESS &&
                            _http_client_bootstrap_fail_setup!(options, setup_reported, channel, tls_status)
                        return nothing
                    end,
                    err -> _http_client_bootstrap_fail_setup!(options, setup_reported, channel, err),
                )
                start_status != OP_SUCCESS &&
                    _http_client_bootstrap_fail_setup!(options, setup_reported, channel, start_status)
                return nothing
            end
            err = _http_client_bootstrap_install_handler!(
                http_bootstrap,
                channel,
                options.tls_connection_options !== nothing,
            )
            if err != OP_SUCCESS
                _http_client_bootstrap_fail_setup!(options, setup_reported, channel, err)
                return nothing
            end
        end

        _http_client_bootstrap_report_success!(http_bootstrap, setup_reported, channel)
        return nothing
    end

    connect_tls = connect_plan.use_tunnel ? nothing : options.tls_connection_options
    try
        return Sockets.client_bootstrap_connect!(
            on_setup,
            connect_plan.connect_host,
            connect_plan.connect_port;
            socket_options = options.socket_options !== nothing ? options.socket_options : Sockets.SocketOptions(),
            tls_connection_options = connect_tls,
            enable_read_back_pressure = false,
            requested_event_loop = options.requested_event_loop,
            event_loop_group = event_loop_group,
        )
    catch err
        error_code = err isa Reseau.ReseauError ? err.code : Reseau.ERROR_UNKNOWN
        _http_client_bootstrap_fail_setup!(options, setup_reported, nothing, error_code)
        return nothing
    end
end
