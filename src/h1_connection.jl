# HTTP/1.1 Connection - Channel handler integrating encoder + decoder with streams
# Port of aws-c-http/source/h1_connection.c, h1_connection.h

using AwsIO: AbstractChannelHandler, ChannelSlot, ChannelDirection,
             IoMessage, ErrorResult, OP_SUCCESS, OP_ERR,
             channel_slot_send_message, channel_slot_on_handler_shutdown_complete!,
             channel_slot_increment_read_window!

# ─── Read state ───

@enumx H1ConnectionReadState::UInt8 begin
    OPEN = 0
    SHUTTING_DOWN = 1
    SHUT_DOWN_COMPLETE = 2
end

# ─── H1 Connection ───

mutable struct H1Connection <: AbstractChannelHandler
    # ── Connection identity ──
    @atomic ref_count::Int
    http_version::HttpVersion.T
    is_client::Bool
    user_data::Any

    # ── Stream management ──
    stream_list::Vector{H1Stream}
    outgoing_stream::Union{H1Stream, Nothing}
    incoming_stream::Union{H1Stream, Nothing}
    next_stream_id::UInt32  # starts at 1 (client) or 2 (server), increments by 2

    # ── Encoder / Decoder ──
    encoder::H1Encoder
    decoder::H1Decoder

    # ── Read state ──
    connection_window::Csize_t
    read_state::H1ConnectionReadState.T

    # ── Flow control ──
    initial_stream_window_size::UInt64
    manual_window_management::Bool

    # ── State flags ──
    is_open::Bool
    is_writing_stopped::Bool
    has_switched_protocols::Bool
    new_stream_error_code::Int

    # ── Shutdown ──
    pending_shutdown_error_code::Int

    # ── Client/Server-specific ──
    response_first_byte_timeout_ms::UInt64
    on_shutdown::Any  # (connection, error_code, user_data) -> Nothing

    # ── Proxy ──
    proxy_request_transform::Any  # (request::HttpMessage, user_data) -> Int  or nothing

    # ── Channel integration ──
    on_channel_handler_installed::Any  # (connection, user_data) -> Nothing  or nothing
    remote_endpoint::String  # host:port or "" if unknown
end

# ─── Decoder vtable callbacks (wired to the H1 decoder) ───

function _conn_decoder_on_request(method_enum, method_str, uri, conn)::Int
    stream = conn.incoming_stream
    stream === nothing && return OP_ERR
    stream.request_method = method_enum
    stream.request_method_str = method_str
    stream.request_path = uri
    return OP_SUCCESS
end

function _conn_decoder_on_response(status_code, conn)::Int
    stream = conn.incoming_stream
    stream === nothing && return OP_ERR
    stream.response_status = status_code
    return OP_SUCCESS
end

function _conn_decoder_on_header(header::H1DecodedHeader, conn)::Int
    stream = conn.incoming_stream
    stream === nothing && return OP_ERR

    # Check for "Connection: close"
    if header.name == HttpHeaderName.CONNECTION
        if lowercase(header.value_data) == "close"
            stream.is_final_stream = true
        end
    end

    # Forward to stream callback
    if stream.on_incoming_headers !== nothing
        h = HttpHeader(header.name_data, header.value_data)
        block = h1_decoder_get_header_block(conn.decoder)
        err = stream.on_incoming_headers(stream, block, [h], stream.user_data)
        err != OP_SUCCESS && return OP_ERR
    end

    return OP_SUCCESS
end

function _conn_decoder_on_body(data::AbstractVector{UInt8}, finished::Bool, conn)::Int
    stream = conn.incoming_stream
    stream === nothing && return OP_ERR

    # Mark head as done on first body callback
    if !stream.is_incoming_head_done
        stream.is_incoming_head_done = true
        if stream.on_incoming_header_block_done !== nothing
            block = h1_decoder_get_header_block(conn.decoder)
            err = stream.on_incoming_header_block_done(stream, block, stream.user_data)
            err != OP_SUCCESS && return OP_ERR
        end
    end

    # Forward body data to stream
    if !isempty(data) && stream.on_incoming_body !== nothing
        err = stream.on_incoming_body(stream, data, stream.user_data)
        err != OP_SUCCESS && return OP_ERR
    end

    return OP_SUCCESS
end

function _conn_decoder_on_done(conn)::Int
    stream = conn.incoming_stream
    stream === nothing && return OP_ERR

    # Ensure head-done fires even for bodyless messages
    if !stream.is_incoming_head_done
        stream.is_incoming_head_done = true
        if stream.on_incoming_header_block_done !== nothing
            block = h1_decoder_get_header_block(conn.decoder)
            err = stream.on_incoming_header_block_done(stream, block, stream.user_data)
            err != OP_SUCCESS && return OP_ERR
        end
    end

    stream.is_incoming_message_done = true

    # If server: on_request_done fires
    if !stream.is_client && stream.on_request_done !== nothing
        stream.on_request_done(stream, stream.user_data)
    end

    # Try to complete the stream
    _try_complete_stream!(conn, stream)

    # Advance incoming pointer to next stream
    _advance_incoming_stream!(conn)

    return OP_SUCCESS
end

# ─── Internal: build decoder vtable for a connection ───

function _make_decoder_vtable()
    return H1DecoderVtable(
        (hdr, ud) -> _conn_decoder_on_header(hdr, ud),
        (data, finished, ud) -> _conn_decoder_on_body(data, finished, ud),
        (me, ms, uri, ud) -> _conn_decoder_on_request(me, ms, uri, ud),
        (sc, ud) -> _conn_decoder_on_response(sc, ud),
        (ud) -> _conn_decoder_on_done(ud),
    )
end

# ─── Constructor ───

"""
    h1_connection_new_client(; kwargs...) -> H1Connection

Create a new HTTP/1.1 client connection.
"""
function h1_connection_new_client(;
    manual_window_management::Bool = false,
    initial_window_size::Csize_t = Csize_t(typemax(Csize_t)),
    user_data = nothing,
    on_shutdown = nothing,
    on_channel_handler_installed = nothing,
    proxy_request_transform = nothing,
    response_first_byte_timeout_ms::UInt64 = UInt64(0),
)::H1Connection
    conn_window = manual_window_management ? initial_window_size : Csize_t(typemax(Csize_t))
    encoder = h1_encoder_init()
    vtable = _make_decoder_vtable()

    # Create connection first with a placeholder decoder
    conn = H1Connection(
        1,  # ref_count
        HttpVersion.HTTP_1_1, true, user_data,
        H1Stream[], nothing, nothing, UInt32(1),
        encoder,
        h1_decoder_new(H1DecoderParams(1024, false, nothing, vtable)),  # placeholder
        conn_window, H1ConnectionReadState.OPEN,
        manual_window_management ? UInt64(initial_window_size) : typemax(UInt64),
        manual_window_management,
        true, false, false, 0, 0,
        response_first_byte_timeout_ms, on_shutdown,
        proxy_request_transform, on_channel_handler_installed, "",
    )

    # Now create decoder with conn as user_data
    conn.decoder = h1_decoder_new(H1DecoderParams(1024, false, conn, vtable))
    return conn
end

"""
    h1_connection_new_server(; kwargs...) -> H1Connection

Create a new HTTP/1.1 server connection.
"""
function h1_connection_new_server(;
    manual_window_management::Bool = false,
    initial_window_size::Csize_t = Csize_t(typemax(Csize_t)),
    user_data = nothing,
    on_shutdown = nothing,
)::H1Connection
    conn_window = manual_window_management ? initial_window_size : Csize_t(typemax(Csize_t))
    encoder = h1_encoder_init()
    vtable = _make_decoder_vtable()

    conn = H1Connection(
        1,  # ref_count
        HttpVersion.HTTP_1_1, false, user_data,
        H1Stream[], nothing, nothing, UInt32(2),
        encoder,
        h1_decoder_new(H1DecoderParams(1024, true, nothing, vtable)),  # placeholder
        conn_window, H1ConnectionReadState.OPEN,
        manual_window_management ? UInt64(initial_window_size) : typemax(UInt64),
        manual_window_management,
        true, false, false, 0, 0,
        UInt64(0), on_shutdown,
        nothing, nothing, "",
    )

    conn.decoder = h1_decoder_new(H1DecoderParams(1024, true, conn, vtable))
    return conn
end

# ─── Connection public API ───

function http_connection_close(conn::H1Connection)::Nothing
    conn.is_open = false
    if conn.new_stream_error_code == 0
        conn.new_stream_error_code = ERROR_HTTP_CONNECTION_CLOSED
    end
    return nothing
end

http_connection_is_open(conn::H1Connection)::Bool = conn.is_open
http_connection_is_client(conn::H1Connection)::Bool = conn.is_client
http_connection_get_version(conn::H1Connection)::HttpVersion.T = conn.http_version

function http_connection_new_requests_allowed(conn::H1Connection)::Bool
    return conn.is_open && conn.new_stream_error_code == 0
end

function http_connection_stop_new_requests(conn::H1Connection)::Nothing
    if conn.new_stream_error_code == 0
        conn.new_stream_error_code = ERROR_HTTP_CONNECTION_CLOSED
    end
    return nothing
end

function http_connection_acquire(conn::H1Connection)::H1Connection
    @atomic conn.ref_count += 1
    return conn
end

function http_connection_release(conn::H1Connection)::Nothing
    old = @atomic conn.ref_count
    @atomic conn.ref_count = old - 1
    return nothing
end

http_connection_get_remote_endpoint(conn::H1Connection)::String = conn.remote_endpoint

function _get_next_stream_id!(conn::H1Connection)::UInt32
    id = conn.next_stream_id
    conn.next_stream_id += UInt32(2)
    return id
end

# ─── Make request (client API) ───

function http_connection_make_request(conn::H1Connection, options::HttpMakeRequestOptions)::Union{H1Stream, Nothing}
    if !conn.is_client
        raise_error(ERROR_INVALID_STATE)
        return nothing
    end
    if conn.new_stream_error_code != 0
        raise_error(conn.new_stream_error_code)
        return nothing
    end
    return h1_stream_new_request(conn, options)
end

# ─── Make server request handler (server API) ───

function http_connection_new_request_handler(conn::H1Connection, options::HttpRequestHandlerOptions)::Union{H1Stream, Nothing}
    if conn.is_client
        raise_error(ERROR_INVALID_STATE)
        return nothing
    end
    if conn.new_stream_error_code != 0
        raise_error(conn.new_stream_error_code)
        return nothing
    end
    return h1_stream_new_request_handler(HttpRequestHandlerOptions(
        conn,  # server_connection
        options.user_data,
        options.on_request_headers,
        options.on_request_header_block_done,
        options.on_request_body,
        options.on_request_done,
        options.on_complete,
        options.on_destroy,
    ))
end

# ─── Stream activation ───

"""
    h1_stream_activate!(stream::H1Stream) -> Int

Activate a stream, adding it to the connection's pipeline.
"""
function h1_stream_activate!(stream::H1Stream)::Int
    conn = stream.owning_connection::H1Connection
    if conn.new_stream_error_code != 0
        return raise_error(conn.new_stream_error_code)
    end

    stream.id = _get_next_stream_id!(conn)
    stream.api_state = H1StreamApiState.ACTIVE
    http_stream_acquire(stream)  # connection holds a ref
    push!(conn.stream_list, stream)

    if conn.incoming_stream === nothing
        conn.incoming_stream = stream
    end

    return OP_SUCCESS
end

# ─── Stream management ───

function _advance_incoming_stream!(conn::H1Connection)
    conn.incoming_stream = nothing
    for s in conn.stream_list
        if !s.is_incoming_message_done
            conn.incoming_stream = s
            return
        end
    end
end

function _try_complete_stream!(conn::H1Connection, stream::H1Stream)
    if stream.is_outgoing_message_done && stream.is_incoming_message_done
        _finish_stream!(conn, stream)
    end
end

function _finish_stream!(conn::H1Connection, stream::H1Stream)
    filter!(s -> s !== stream, conn.stream_list)

    if conn.outgoing_stream === stream
        conn.outgoing_stream = nothing
    end
    if conn.incoming_stream === stream
        _advance_incoming_stream!(conn)
    end

    _stream_complete!(stream, 0)

    if stream.is_final_stream
        conn.is_open = false
        if conn.new_stream_error_code == 0
            conn.new_stream_error_code = ERROR_HTTP_CONNECTION_CLOSED
        end
    end
end

# ─── Write path: encode outgoing stream data ───

"""
    h1_connection_encode_outgoing!(conn) -> (Int, Vector{UInt8})

Encode the current outgoing stream's data into bytes.
Returns `(status, encoded_bytes)`. The caller is responsible for
transmitting the bytes (e.g., via channel or directly to socket).
"""
function h1_connection_encode_outgoing!(conn::H1Connection)::Tuple{Int, Vector{UInt8}}
    if conn.outgoing_stream === nothing
        _update_outgoing_stream!(conn)
    end

    stream = conn.outgoing_stream
    stream === nothing && return (OP_SUCCESS, UInt8[])
    stream.encoder_message === nothing && return (OP_SUCCESS, UInt8[])

    if !h1_encoder_is_message_in_progress(conn.encoder)
        err = h1_encoder_start_message!(conn.encoder, stream.encoder_message)
        err != OP_SUCCESS && return (OP_ERR, UInt8[])
    end

    dst = IOBuffer(; maxsize=16384)
    err = h1_encoder_process!(conn.encoder, dst)
    err != OP_SUCCESS && return (OP_ERR, UInt8[])

    encoded = take!(dst)

    if !h1_encoder_is_message_in_progress(conn.encoder)
        stream.is_outgoing_message_done = true
        h1_encoder_message_clean_up!(stream.encoder_message)
        _try_complete_stream!(conn, stream)
        conn.outgoing_stream = nothing
        _update_outgoing_stream!(conn)
    end

    return (OP_SUCCESS, encoded)
end

function _update_outgoing_stream!(conn::H1Connection)
    for s in conn.stream_list
        if s.encoder_message !== nothing && !s.is_outgoing_message_done
            conn.outgoing_stream = s
            return
        end
    end
    conn.outgoing_stream = nothing
end

# ─── Read path: decode incoming data ───

"""
    h1_connection_process_read_data!(conn, data) -> Int

Feed incoming data to the decoder. Decoder callbacks fire and
dispatch to the current incoming stream.
"""
function h1_connection_process_read_data!(conn::H1Connection, data::AbstractVector{UInt8})::Int
    conn.incoming_stream === nothing && return OP_SUCCESS
    status, consumed = h1_decode!(conn.decoder, data)
    status != OP_SUCCESS && return OP_ERR
    return OP_SUCCESS
end

function h1_connection_process_read_data!(conn::H1Connection, data::AbstractString)::Int
    return h1_connection_process_read_data!(conn, Vector{UInt8}(codeunits(String(data))))
end

# ─── Connection cleanup ───

function h1_connection_destroy!(conn::H1Connection)::Nothing
    # Complete any remaining streams with error
    for stream in copy(conn.stream_list)
        _stream_complete!(stream, ERROR_HTTP_CONNECTION_CLOSED)
    end
    empty!(conn.stream_list)
    conn.incoming_stream = nothing
    conn.outgoing_stream = nothing

    h1_encoder_clean_up!(conn.encoder)
    h1_decoder_destroy!(conn.decoder)
    return nothing
end

# ─── Channel handler interface ───
# These methods integrate H1Connection into the AwsIO channel pipeline.

function AwsIO.handler_process_read_message(conn::H1Connection, slot::ChannelSlot, message::IoMessage)::Union{Nothing, ErrorResult}
    data = AwsIO.byte_buffer_as_vector(message.message_data)
    if !isempty(data)
        err = h1_connection_process_read_data!(conn, data)
        err != OP_SUCCESS && return ErrorResult(ERROR_HTTP_PROTOCOL_ERROR)
    end
    return nothing
end

function AwsIO.handler_process_write_message(conn::H1Connection, slot::ChannelSlot, message::IoMessage)::Union{Nothing, ErrorResult}
    return channel_slot_send_message(slot, message, ChannelDirection.WRITE)
end

function AwsIO.handler_increment_read_window(conn::H1Connection, slot::ChannelSlot, size::Csize_t)::Union{Nothing, ErrorResult}
    return channel_slot_increment_read_window!(slot, size)
end

function AwsIO.handler_shutdown(
    conn::H1Connection,
    slot::ChannelSlot,
    direction::ChannelDirection.T,
    error_code::Int,
    free_scarce_resources_immediately::Bool,
)::Union{Nothing, ErrorResult}
    conn.is_open = false
    err_code = error_code != 0 ? error_code : ERROR_HTTP_CONNECTION_CLOSED
    conn.new_stream_error_code = err_code

    for stream in copy(conn.stream_list)
        _stream_complete!(stream, err_code)
    end
    empty!(conn.stream_list)
    conn.incoming_stream = nothing
    conn.outgoing_stream = nothing

    channel_slot_on_handler_shutdown_complete!(slot, direction, error_code, free_scarce_resources_immediately)
    return nothing
end

AwsIO.handler_initial_window_size(conn::H1Connection)::Csize_t = conn.connection_window
AwsIO.handler_message_overhead(conn::H1Connection)::Csize_t = Csize_t(0)

function AwsIO.handler_destroy(conn::H1Connection)::Nothing
    h1_connection_destroy!(conn)
    return nothing
end
