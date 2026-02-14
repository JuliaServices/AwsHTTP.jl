# HTTP Connection - Base connection types and public API
# Port of aws-c-http/source/connection.c, connection_impl.h, connection.h

# ─── Connection monitoring options ───

struct HttpConnectionMonitoringOptions
    minimum_throughput_bytes_per_second::UInt64
    allowable_throughput_failure_interval_seconds::UInt32
end

# ─── HTTP/1 connection options ───

struct Http1ConnectionOptions
    read_buffer_capacity::Csize_t  # 0 = default
end

Http1ConnectionOptions() = Http1ConnectionOptions(Csize_t(0))

# ─── Client connection options ───

struct HttpClientConnectionOptions{BS, SO, TLS, ALPN <: Union{HttpAlpnMap, Nothing}, UD, FS, FSD, H2O, REL, PO, MO <: Union{HttpConnectionMonitoringOptions, Nothing}}
    # ── Networking ──
    bootstrap::BS  # ClientBootstrap - initiates socket connection
    socket_options::SO  # SocketOptions - TCP/UDP settings
    tls_connection_options::TLS  # TlsConnectionOptions or nothing
    # ── Host/port ──
    host_name::String
    port::UInt32
    # ── ALPN/Version ──
    alpn_string_map::ALPN  # ALPN protocol → HttpVersion map
    prior_knowledge_http2::Bool  # skip ALPN, assume HTTP/2
    h2c_upgrade::Bool  # attempt HTTP/2 cleartext upgrade via Upgrade: h2c
    # ── Window management ──
    manual_window_management::Bool
    initial_window_size::Csize_t
    # ── Callbacks ──
    user_data::UD
    on_setup::FS        # (connection_or_nothing, error_code, user_data) -> Nothing
    on_shutdown::FSD    # (connection, error_code, user_data) -> Nothing
    # ── Timeouts ──
    response_first_byte_timeout_ms::UInt64
    # ── Protocol-specific options ──
    http1_options::Http1ConnectionOptions
    http2_options::H2O  # Http2ConnectionOptions or nothing
    # ── Advanced ──
    requested_event_loop::REL  # pin to specific event loop, or nothing
    proxy_options::PO  # proxy configuration, or nothing
    monitoring_options::MO
end

function _dispatch_user_callback(f, args...; subject::LogSubject = LS_HTTP_CONNECTION, label::AbstractString = "callback")
    f === nothing && return nothing
    Reseau.logf(Reseau.LogLevel.TRACE, subject, "HTTP user $label dispatching")
    errormonitor(Threads.@spawn begin
        try
            Reseau.logf(Reseau.LogLevel.TRACE, subject, "HTTP user $label starting")
            Base.invokelatest(f, args...)
        catch err
            Reseau.logf(
                Reseau.LogLevel.ERROR,
                subject,
                string("HTTP user ", label, " threw: ", sprint(showerror, err, catch_backtrace())),
            )
        end
    end)
    return nothing
end

function HttpClientConnectionOptions(;
    bootstrap,
    host_name::String,
    port::UInt32,
    socket_options = nothing,
    tls_connection_options = nothing,
    alpn_string_map::Union{HttpAlpnMap, Nothing} = nothing,
    prior_knowledge_http2::Bool = false,
    h2c_upgrade::Bool = false,
    user_data = nothing,
    on_setup = nothing,
    on_shutdown = nothing,
    manual_window_management::Bool = false,
    initial_window_size::Csize_t = Csize_t(typemax(Csize_t)),
    response_first_byte_timeout_ms::UInt64 = UInt64(0),
    http1_options::Http1ConnectionOptions = Http1ConnectionOptions(),
    http2_options = nothing,
    requested_event_loop = nothing,
    proxy_options = nothing,
    monitoring_options::Union{HttpConnectionMonitoringOptions, Nothing} = nothing,
)
    return HttpClientConnectionOptions(
        bootstrap, socket_options, tls_connection_options,
        host_name, port,
        alpn_string_map, prior_knowledge_http2, h2c_upgrade,
        manual_window_management, initial_window_size,
        user_data, on_setup, on_shutdown,
        response_first_byte_timeout_ms,
        http1_options, http2_options,
        requested_event_loop, proxy_options, monitoring_options,
    )
end

# ─── Abstract connection interface ───
# Concrete connections (H1Connection, H2Connection) implement these functions via dispatch.

"""
    http_connection_close(connection) -> Nothing

Begin graceful shutdown of the connection.
"""
function http_connection_close end

"""
    http_connection_is_open(connection) -> Bool

Return whether the connection is still open.
"""
function http_connection_is_open end

"""
    http_connection_new_requests_allowed(connection) -> Bool

Return whether new requests can be created on this connection.
"""
function http_connection_new_requests_allowed end

"""
    http_connection_is_client(connection) -> Bool

Return whether this connection is in client mode.
"""
function http_connection_is_client end

"""
    http_connection_get_version(connection) -> HttpVersion.T

Return the HTTP version of this connection.
"""
function http_connection_get_version end

"""
    http_connection_make_request(connection, options::HttpMakeRequestOptions) -> H1Stream

Create a new client request stream on this connection.
"""
function http_connection_make_request end

"""
    http_connection_stop_new_requests(connection) -> Nothing

Stop accepting new requests on this connection.
"""
function http_connection_stop_new_requests end

"""
    http_connection_new_request_handler(connection, options) -> H1Stream

Create a new server request handler stream on this connection (server only).
"""
function http_connection_new_request_handler end

"""
    http_connection_get_remote_endpoint(connection) -> String

Return the remote endpoint string (host:port or empty).
"""
function http_connection_get_remote_endpoint end

"""
    http_connection_has_switched_protocols(connection) -> Bool

Return whether the connection has completed a 101 Switching Protocols exchange.
"""
function http_connection_has_switched_protocols end

"""
    http_connection_get_pipeline(connection) -> Union{PipelineState, Nothing}

Return the pipeline associated with this connection, or nothing if not yet installed.
"""
function http_connection_get_pipeline end

function _http_version_from_alpn_protocol(protocol::Reseau.ByteBuffer, alpn_map::Union{HttpAlpnMap, Nothing})::HttpVersion.T
    protocol.len == 0 && return HttpVersion.HTTP_1_1
    protocol_str = Reseau.byte_buffer_as_string(protocol)
    if alpn_map !== nothing
        version = http_alpn_map_get(alpn_map, protocol_str)
        if version == HttpVersion.UNKNOWN
            Reseau.logf(
                Reseau.LogLevel.ERROR,
                LS_HTTP_CONNECTION,
                string("Customized ALPN protocol ", protocol_str, " used. However it is not found in the ALPN map provided."),
            )
        else
            Reseau.logf(
                Reseau.LogLevel.DEBUG,
                LS_HTTP_CONNECTION,
                string("Customized ALPN protocol ", protocol_str, " used. ", http_version_to_str(version), " connection established."),
            )
        end
        return version
    end
    if protocol_str == "http/1.1"
        return HttpVersion.HTTP_1_1
    elseif protocol_str == "h2"
        return HttpVersion.HTTP_2
    end
    Reseau.logf(Reseau.LogLevel.WARN, LS_HTTP_CONNECTION, "Unrecognized ALPN protocol. Assuming HTTP/1.1")
    Reseau.logf(Reseau.LogLevel.DEBUG, LS_HTTP_CONNECTION, string("Unrecognized ALPN protocol ", protocol_str))
    return HttpVersion.HTTP_1_1
end

function _http_select_version_from_pipeline(
        pipeline,
        is_using_tls::Bool,
        prior_knowledge_http2::Bool,
        alpn_map::Union{HttpAlpnMap, Nothing},
    )
    version = HttpVersion.HTTP_1_1
    if is_using_tls
        protocol = nothing
        # Check TLS handler on pipeline for negotiated protocol
        tls = pipeline.tls_handler
        if tls !== nothing
            protocol = Sockets.tls_handler_protocol(tls)
        else
            # Apple Network.framework TLS: protocol comes from the socket
            socket = pipeline.socket
            if socket isa Sockets.Socket
                protocol = Sockets.socket_get_protocol(socket::Sockets.Socket)
            end
        end

        if protocol === nothing
            Reseau.logf(Reseau.LogLevel.ERROR, LS_HTTP_CONNECTION, "Failed to find TLS handler or socket protocol in pipeline.")
            Reseau.throw_error(ERROR_INVALID_STATE)
        end

        if protocol.len > 0
            version = _http_version_from_alpn_protocol(protocol, alpn_map)
        end
    elseif prior_knowledge_http2
        Reseau.logf(Reseau.LogLevel.TRACE, LS_HTTP_CONNECTION, "Using prior knowledge to start HTTP/2 connection")
        version = HttpVersion.HTTP_2
    end
    return version
end
