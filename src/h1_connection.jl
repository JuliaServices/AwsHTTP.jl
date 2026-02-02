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
    http_version::HttpVersion.T
    is_client::Bool
    # late-init: reassigned via http_connection_configure_server
    user_data::Any
    on_incoming_request::Any
    on_h2c_upgrade::Any
    server_configured::Bool

    # ── Stream management ──
    stream_list::Vector{H1Stream}
    # late-init: starts nothing, mutated during stream lifecycle
    outgoing_stream::Union{H1Stream, Nothing}
    incoming_stream::Union{H1Stream, Nothing}
    next_stream_id::UInt32  # starts at 1 (client) or 2 (server), increments by 2

    # ── Encoder / Decoder ──
    encoder::H1Encoder
    decoder::H1Decoder

    # ── Read state ──
    connection_window::Csize_t
    read_buffer_capacity::Csize_t  # 0 = unlimited
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
    # late-init: set by channel_slot_set_handler!
    slot::Union{AwsIO.ChannelSlot, Nothing}
    on_channel_handler_installed::Any  # (connection, user_data) -> Nothing  or nothing
    remote_endpoint::String  # host:port or "" if unknown
end

# Set the channel slot when installed in a pipeline.
function AwsIO.setchannelslot!(handler::H1Connection, slot::ChannelSlot)::Nothing
    handler.slot = slot
    return nothing
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
    if stream.is_client
        ignore_body = h1_decoder_get_body_headers_ignored(conn.decoder) || (stream.request_method == HttpMethod.HEAD)
        h1_decoder_set_body_headers_ignored!(conn.decoder, ignore_body)
    end
    # Record receive-start timestamp on first response line (if not yet set)
    if stream.metrics.receive_start_timestamp_ns < 0
        stream.metrics = HttpStreamMetrics(
            stream.metrics.send_start_timestamp_ns,
            stream.metrics.send_end_timestamp_ns,
            stream.metrics.sending_duration_ns,
            time_ns() % Int64,
            stream.metrics.receive_end_timestamp_ns,
            stream.metrics.receiving_duration_ns,
            stream.metrics.stream_id,
        )
        _cancel_response_first_byte_timeout!(conn, stream)
    end
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

    # Record receive-start timestamp on first body data
    if stream.metrics.receive_start_timestamp_ns < 0
        stream.metrics = HttpStreamMetrics(
            stream.metrics.send_start_timestamp_ns,
            stream.metrics.send_end_timestamp_ns,
            stream.metrics.sending_duration_ns,
            time_ns() % Int64,
            stream.metrics.receive_end_timestamp_ns,
            stream.metrics.receiving_duration_ns,
            stream.metrics.stream_id,
        )
        _cancel_response_first_byte_timeout!(conn, stream)
    end

    # Mark head as done on first body callback
    if !stream.is_incoming_head_done
        stream.is_incoming_head_done = true
        if stream.on_incoming_header_block_done !== nothing
            block = h1_decoder_get_header_block(conn.decoder)
            err = stream.on_incoming_header_block_done(stream, block, stream.user_data)
            err != OP_SUCCESS && return OP_ERR
        end
    end

    # Flow control: decrement stream window
    data_len = UInt64(length(data))
    if conn.manual_window_management && data_len > 0
        if data_len > stream.stream_window
            return raise_error(ERROR_HTTP_STREAM_WINDOW_EXCEEDED)
        end
        stream.stream_window -= data_len
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

    # Check if this was an informational (1xx) response.
    # 101 Switching Protocols is 1xx but is a final response — complete normally.
    block = h1_decoder_get_header_block(conn.decoder)
    if block == HttpHeaderBlock.INFORMATIONAL &&
       stream.response_status != HTTP_STATUS_CODE_101_SWITCHING_PROTOCOLS
        # Fire header_block_done for the informational block, then reset for real response
        if !stream.is_incoming_head_done
            if stream.on_incoming_header_block_done !== nothing
                err = stream.on_incoming_header_block_done(stream, block, stream.user_data)
                err != OP_SUCCESS && return OP_ERR
            end
        end
        # Do NOT mark head or message as done — wait for the actual response
        return OP_SUCCESS
    end

    # Ensure head-done fires even for bodyless messages
    if !stream.is_incoming_head_done
        stream.is_incoming_head_done = true
        if stream.on_incoming_header_block_done !== nothing
            err = stream.on_incoming_header_block_done(stream, block, stream.user_data)
            err != OP_SUCCESS && return OP_ERR
        end
    end

    stream.is_incoming_message_done = true

    # Record receive-end timestamp and receiving duration
    now = time_ns() % Int64
    recv_start = stream.metrics.receive_start_timestamp_ns
    recv_dur = recv_start >= 0 ? (now - recv_start) : Int64(-1)
    stream.metrics = HttpStreamMetrics(
        stream.metrics.send_start_timestamp_ns,
        stream.metrics.send_end_timestamp_ns,
        stream.metrics.sending_duration_ns,
        recv_start, now, recv_dur,
        stream.id,
    )

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
    read_buffer_capacity::Csize_t = Csize_t(0),
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
        HttpVersion.HTTP_1_1, true, user_data,
        nothing, nothing, false,
        H1Stream[], nothing, nothing, UInt32(1),
        encoder,
        h1_decoder_new(H1DecoderParams(1024, false, nothing, vtable)),  # placeholder
        conn_window, read_buffer_capacity, H1ConnectionReadState.OPEN,
        manual_window_management ? UInt64(initial_window_size) : typemax(UInt64),
        manual_window_management,
        true, false, false, 0, 0,
        response_first_byte_timeout_ms, on_shutdown,
        proxy_request_transform, nothing, on_channel_handler_installed, "",
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
    read_buffer_capacity::Csize_t = Csize_t(0),
    user_data = nothing,
    on_shutdown = nothing,
)::H1Connection
    conn_window = manual_window_management ? initial_window_size : Csize_t(typemax(Csize_t))
    encoder = h1_encoder_init()
    vtable = _make_decoder_vtable()

    conn = H1Connection(
        HttpVersion.HTTP_1_1, false, user_data,
        nothing, nothing, false,
        H1Stream[], nothing, nothing, UInt32(2),
        encoder,
        h1_decoder_new(H1DecoderParams(1024, true, nothing, vtable)),  # placeholder
        conn_window, read_buffer_capacity, H1ConnectionReadState.OPEN,
        manual_window_management ? UInt64(initial_window_size) : typemax(UInt64),
        manual_window_management,
        true, false, false, 0, 0,
        UInt64(0), on_shutdown,
        nothing, nothing, nothing, "",
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

http_connection_get_remote_endpoint(conn::H1Connection)::String = conn.remote_endpoint

"""
    http_connection_has_switched_protocols(conn) -> Bool

Return whether this connection has completed a 101 Switching Protocols exchange.
"""
http_connection_has_switched_protocols(conn::H1Connection)::Bool = conn.has_switched_protocols

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

    _cancel_response_first_byte_timeout!(conn, stream)
    _stream_complete!(stream, 0)

    if stream.is_final_stream
        conn.is_open = false
        if conn.new_stream_error_code == 0
            conn.new_stream_error_code = ERROR_HTTP_CONNECTION_CLOSED
        end
        if conn.slot !== nothing
            AwsIO.channel_shutdown!(conn.slot.channel; shutdown_immediately=true)
        end
    end

    # Detect 101 Switching Protocols
    if stream.is_client && stream.response_status == HTTP_STATUS_CODE_101_SWITCHING_PROTOCOLS
        conn.has_switched_protocols = true
        if conn.new_stream_error_code == 0
            conn.new_stream_error_code = ERROR_HTTP_SWITCHED_PROTOCOLS
        end
    end
end

function _response_first_byte_timeout_task(ctx, status::AwsIO.TaskStatus.T)
    status == AwsIO.TaskStatus.RUN_READY || return nothing
    stream = ctx.stream
    stream.api_state == H1StreamApiState.COMPLETE && return nothing
    conn = stream.owning_connection
    if conn.slot !== nothing
        AwsIO.channel_shutdown!(conn.slot.channel, ERROR_HTTP_RESPONSE_FIRST_BYTE_TIMEOUT; shutdown_immediately=true)
    else
        _stream_complete!(stream, ERROR_HTTP_RESPONSE_FIRST_BYTE_TIMEOUT)
    end
    return nothing
end

function _schedule_response_first_byte_timeout!(conn::H1Connection, stream::H1Stream)::Nothing
    conn.slot === nothing && return nothing
    stream.metrics.receive_start_timestamp_ns >= 0 && return nothing
    timeout_ms = stream.response_first_byte_timeout_ms == 0 ? conn.response_first_byte_timeout_ms : stream.response_first_byte_timeout_ms
    timeout_ms == 0 && return nothing
    task = stream.response_first_byte_timeout_task
    if task === nothing
        task = AwsIO.ScheduledTask(_response_first_byte_timeout_task, (stream = stream,); type_tag = "http_response_first_byte_timeout")
        stream.response_first_byte_timeout_task = task
    end
    task.scheduled && return nothing
    event_loop = conn.slot.channel.event_loop
    now = AwsIO.event_loop_current_clock_time(event_loop)
    now isa ErrorResult && return nothing
    AwsIO.event_loop_schedule_task_future!(event_loop, task, now + timeout_ms * 1_000_000)
    return nothing
end

function _cancel_response_first_byte_timeout!(conn::H1Connection, stream::H1Stream)::Nothing
    task = stream.response_first_byte_timeout_task
    task === nothing && return nothing
    conn.slot === nothing && return nothing
    if task.scheduled
        AwsIO.event_loop_cancel_task!(conn.slot.channel.event_loop, task)
    end
    return nothing
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
        # Record send-start timestamp
        if stream.metrics.send_start_timestamp_ns < 0
            stream.metrics = HttpStreamMetrics(
                time_ns() % Int64,
                stream.metrics.send_end_timestamp_ns,
                stream.metrics.sending_duration_ns,
                stream.metrics.receive_start_timestamp_ns,
                stream.metrics.receive_end_timestamp_ns,
                stream.metrics.receiving_duration_ns,
                stream.metrics.stream_id,
            )
        end
    end

    dst = IOBuffer(; maxsize=16384)
    err = h1_encoder_process!(conn.encoder, dst)
    err != OP_SUCCESS && return (OP_ERR, UInt8[])

    encoded = take!(dst)

    if !h1_encoder_is_message_in_progress(conn.encoder)
        stream.is_outgoing_message_done = true
        # Record send-end timestamp and sending duration
        now = time_ns() % Int64
        send_start = stream.metrics.send_start_timestamp_ns
        sending_dur = send_start >= 0 ? (now - send_start) : Int64(-1)
        stream.metrics = HttpStreamMetrics(
            send_start, now, sending_dur,
            stream.metrics.receive_start_timestamp_ns,
            stream.metrics.receive_end_timestamp_ns,
            stream.metrics.receiving_duration_ns,
            stream.metrics.stream_id,
        )
        h1_encoder_message_clean_up!(stream.encoder_message)
        stream.encoder_message = nothing
        _schedule_response_first_byte_timeout!(conn, stream)
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

function _ensure_server_incoming_stream!(conn::H1Connection)::Union{Nothing, ErrorResult}
    if conn.incoming_stream !== nothing || conn.is_client || conn.on_incoming_request === nothing
        return nothing
    end
    stream = conn.on_incoming_request(conn, conn.user_data)
    stream === nothing && return ErrorResult(raise_error(ERROR_HTTP_REACTION_REQUIRED))
    if !(stream isa H1Stream)
        return ErrorResult(raise_error(ERROR_INVALID_ARGUMENT))
    end
    if stream.api_state == H1StreamApiState.INIT
        status = h1_stream_activate!(stream)
        status != OP_SUCCESS && return ErrorResult(status)
    end
    return nothing
end

"""
    h1_connection_process_read_data!(conn, data) -> Int

Feed incoming data to the decoder. Decoder callbacks fire and
dispatch to the current incoming stream.
"""
function h1_connection_process_read_data!(conn::H1Connection, data::AbstractVector{UInt8})::Int
    if conn.incoming_stream === nothing
        ensure = _ensure_server_incoming_stream!(conn)
        ensure isa ErrorResult && return OP_ERR
        conn.incoming_stream === nothing && return OP_SUCCESS
    end
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
    result = nothing
    if !isempty(data)
        err = h1_connection_process_read_data!(conn, data)
        err != OP_SUCCESS && (result = ErrorResult(ERROR_HTTP_PROTOCOL_ERROR))
    end

    if slot.channel !== nothing
        inc_res = channel_slot_increment_read_window!(slot, message.message_data.len)
        if result === nothing && inc_res isa ErrorResult
            result = inc_res
        end
        AwsIO.channel_release_message_to_pool!(slot.channel, message)
    end

    return result
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
        _cancel_response_first_byte_timeout!(conn, stream)
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
