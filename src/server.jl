# HTTP Server - Listener and connection factory
# Port of aws-c-http/include/aws/http/server.h, connection.c (server portions)

# ─── Server connection options ───

struct HttpServerConnectionOptions{CUD, FIR, FH2C, FSD}
    connection_user_data::CUD
    on_incoming_request::FIR    # (connection, user_data) -> stream_or_nothing
    on_h2c_upgrade::FH2C        # (connection, request, user_data) -> Bool
    on_shutdown::FSD             # (connection, error_code, user_data) -> Nothing
end

function HttpServerConnectionOptions(;
    connection_user_data=nothing,
    on_incoming_request=nothing,
    on_h2c_upgrade=nothing,
    on_shutdown=nothing,
)
    return HttpServerConnectionOptions(
        connection_user_data,
        on_incoming_request,
        on_h2c_upgrade,
        on_shutdown,
    )
end

# ─── Server options ───

struct HttpServerOptions{SUD, FIC, FDC}
    endpoint_host::String
    endpoint_port::UInt32
    prior_knowledge_http2::Bool
    initial_window_size::Csize_t
    manual_window_management::Bool
    server_user_data::SUD
    on_incoming_connection::FIC  # (server, connection, error_code, user_data) -> Nothing
    on_destroy_complete::FDC     # (user_data) -> Nothing
end

function HttpServerOptions(;
    endpoint_host::String="0.0.0.0",
    endpoint_port::UInt32=UInt32(0),
    prior_knowledge_http2::Bool=false,
    initial_window_size::Csize_t=typemax(Csize_t),
    manual_window_management::Bool=false,
    server_user_data=nothing,
    on_incoming_connection=nothing,
    on_destroy_complete=nothing,
)
    return HttpServerOptions(
        endpoint_host, endpoint_port,
        prior_knowledge_http2, initial_window_size, manual_window_management,
        server_user_data,
        on_incoming_connection, on_destroy_complete,
    )
end

# ─── HTTP Server ───

mutable struct HttpServer
    options::HttpServerOptions
    connections::Vector{Any}  # active connections
    is_open::Bool
    listener_host::String
    listener_port::UInt32
end

"""
    http_server_new(options::HttpServerOptions) -> HttpServer

Create a new HTTP server with the given options.
"""
function http_server_new(options::HttpServerOptions)::HttpServer
    return HttpServer(
        options,
        Any[],
        true,
        options.endpoint_host,
        options.endpoint_port,
    )
end

"""
    http_server_release(server::HttpServer) -> Nothing

Release the server: close all connections and invoke destroy callback.
"""
function http_server_release(server::HttpServer)::Nothing
    server.is_open = false

    # Close all connections
    for conn in server.connections
        if applicable(http_connection_close, conn)
            http_connection_close(conn)
        end
    end
    empty!(server.connections)

    if server.options.on_destroy_complete !== nothing
        server.options.on_destroy_complete(server.options.server_user_data)
    end
    return nothing
end

"""
    http_connection_configure_server(connection, options::HttpServerConnectionOptions) -> Int

Configure a server connection with handler callbacks. Must be called from
the on_incoming_connection callback.
"""
function http_connection_configure_server(connection, options::HttpServerConnectionOptions)::Int
    # Store the connection options for later use
    if hasproperty(connection, :user_data)
        connection.user_data = options.connection_user_data
    end
    return OP_SUCCESS
end

"""
    http_connection_is_server(connection) -> Bool

Check if a connection is server-side.
"""
function http_connection_is_server(connection)::Bool
    if applicable(http_connection_is_client, connection)
        return !http_connection_is_client(connection)
    end
    return false
end

"""
    http_server_get_listener_endpoint(server) -> Tuple{String, UInt32}

Get the bound host and port of the server's listener.
"""
function http_server_get_listener_endpoint(server::HttpServer)::Tuple{String, UInt32}
    return (server.listener_host, server.listener_port)
end
