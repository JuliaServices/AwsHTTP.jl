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

struct HttpClientConnectionOptions
    host_name::String
    port::UInt32
    manual_window_management::Bool
    initial_window_size::Csize_t
    user_data::Any
    on_setup::Any       # (connection_or_nothing, error_code, user_data) -> Nothing
    on_shutdown::Any    # (connection, error_code, user_data) -> Nothing
    response_first_byte_timeout_ms::UInt64
    http1_options::Http1ConnectionOptions
end

function HttpClientConnectionOptions(;
    host_name::String,
    port::UInt32,
    user_data = nothing,
    on_setup = nothing,
    on_shutdown = nothing,
    manual_window_management::Bool = false,
    initial_window_size::Csize_t = Csize_t(typemax(Csize_t)),
    response_first_byte_timeout_ms::UInt64 = UInt64(0),
    http1_options::Http1ConnectionOptions = Http1ConnectionOptions(),
)
    return HttpClientConnectionOptions(
        host_name, port,
        manual_window_management, initial_window_size,
        user_data, on_setup, on_shutdown,
        response_first_byte_timeout_ms,
        http1_options,
    )
end

# ─── Abstract connection interface ───
# Concrete connections (H1Connection) implement these functions via dispatch.

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
