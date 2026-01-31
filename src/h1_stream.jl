# HTTP/1.1 Stream - Client/server stream on an H1 connection
# Port of aws-c-http/source/h1_stream.c, h1_stream.h, request_response_impl.h

# ─── Stream API state ───

@enumx H1StreamApiState::UInt8 begin
    INIT = 0
    ACTIVE = 1
    COMPLETE = 2
end

# ─── Callback types (see Phase 5.5 of parity roadmap) ───
# All callbacks are stored as `Any` to allow flexible function types.
# Signature conventions:
#   on_incoming_headers(stream, header_block, headers::Vector{HttpHeader}, user_data) -> Int
#   on_incoming_header_block_done(stream, header_block, user_data) -> Int
#   on_incoming_body(stream, data::AbstractVector{UInt8}, user_data) -> Int
#   on_stream_complete(stream, error_code::Int, user_data) -> Nothing
#   on_stream_destroy(user_data) -> Nothing
#   on_stream_metrics(stream, metrics::HttpStreamMetrics, user_data) -> Nothing

# ─── Make-request options (client) ───

struct HttpMakeRequestOptions{UD, FRH, FRHBD, FRB, FM, FC, FD, HP, FH2C}
    request::HttpMessage
    user_data::UD
    on_response_headers::FRH       # (stream, header_block, headers, user_data) -> Int
    on_response_header_block_done::FRHBD  # (stream, header_block, user_data) -> Int
    on_response_body::FRB          # (stream, data, user_data) -> Int
    on_metrics::FM                 # (stream, metrics, user_data) -> Nothing
    on_complete::FC                # (stream, error_code, user_data) -> Nothing
    on_destroy::FD                 # (user_data) -> Nothing
    response_first_byte_timeout_ms::UInt64
    # ── H2-specific options ──
    http2_use_manual_data_writes::Bool
    http2_priority::HP  # Http2Priority or nothing
    http2_headers_pad_length::UInt32
    # ── h2c upgrade ──
    h2c_upgrade::Bool  # attempt HTTP/2 cleartext upgrade on this request
    on_h2c_upgrade::FH2C  # (stream, error_code, user_data) -> Nothing
end

function HttpMakeRequestOptions(;
    request::HttpMessage,
    user_data = nothing,
    on_response_headers = nothing,
    on_response_header_block_done = nothing,
    on_response_body = nothing,
    on_metrics = nothing,
    on_complete = nothing,
    on_destroy = nothing,
    response_first_byte_timeout_ms::UInt64 = UInt64(0),
    http2_use_manual_data_writes::Bool = false,
    http2_priority = nothing,
    http2_headers_pad_length::UInt32 = UInt32(0),
    h2c_upgrade::Bool = false,
    on_h2c_upgrade = nothing,
)
    return HttpMakeRequestOptions(
        request, user_data,
        on_response_headers, on_response_header_block_done,
        on_response_body, on_metrics, on_complete, on_destroy,
        response_first_byte_timeout_ms,
        http2_use_manual_data_writes, http2_priority, http2_headers_pad_length,
        h2c_upgrade, on_h2c_upgrade,
    )
end

# ─── Request handler options (server) ───

struct HttpRequestHandlerOptions{SC, UD, FRH, FRHBD, FRB, FRD, FC, FD}
    server_connection::SC  # H1Connection
    user_data::UD
    on_request_headers::FRH
    on_request_header_block_done::FRHBD
    on_request_body::FRB
    on_request_done::FRD
    on_complete::FC
    on_destroy::FD
end

# ─── H1 Stream ───

mutable struct H1Stream{OC, UD, FIH, FIHBD, FIB, FM, FC, FD, FRD}
    # ── Base stream fields ──
    owning_connection::OC  # H1Connection (forward ref)
    id::UInt32
    @atomic refcount::Int
    request_method::HttpMethod.T
    metrics::HttpStreamMetrics

    # Callbacks
    user_data::UD
    on_incoming_headers::FIH
    on_incoming_header_block_done::FIHBD
    on_incoming_body::FIB
    on_metrics::FM
    on_complete::FC
    on_destroy::FD

    # Client-specific
    response_status::Int
    response_first_byte_timeout_ms::UInt64

    # Server-specific
    request_method_str::String
    request_path::String
    on_request_done::FRD

    is_client::Bool

    # ── Thread data (event-loop thread only) ──
    # late-init: starts nothing, assigned during message start
    encoder_message::Union{H1EncoderMessage, Nothing}
    is_outgoing_message_done::Bool
    is_incoming_message_done::Bool
    is_incoming_head_done::Bool
    is_final_stream::Bool
    stream_window::UInt64
    has_outgoing_response::Bool

    # ── Synced data ──
    api_state::H1StreamApiState.T
end

"""
    h1_stream_new_request(connection, options::HttpMakeRequestOptions) -> H1Stream

Create a new client request stream. The stream is not yet active; call `h1_stream_activate!`.
"""
function h1_stream_new_request(connection, options::HttpMakeRequestOptions)::Union{H1Stream, Nothing}
    msg = options.request
    method_str = http_message_get_request_method(msg)
    method_enum = http_str_to_method(method_str)

    # Build encoder message from request
    enc_msg = H1EncoderMessage()
    err = h1_encoder_message_init_from_request!(enc_msg, msg)
    err != OP_SUCCESS && return nothing  # should not happen if request is valid

    stream = H1Stream(
        connection,
        UInt32(0),   # id assigned on activation
        1,           # refcount
        method_enum,
        HttpStreamMetrics(),
        # callbacks
        options.user_data,
        options.on_response_headers,
        options.on_response_header_block_done,
        options.on_response_body,
        options.on_metrics,
        options.on_complete,
        options.on_destroy,
        # client
        HTTP_STATUS_CODE_UNKNOWN,
        options.response_first_byte_timeout_ms,
        # server (unused for client)
        "", "", nothing,
        true,  # is_client
        # thread data
        enc_msg,
        false, false, false, false,
        typemax(UInt64),  # stream_window (auto: unlimited)
        false,
        # synced
        H1StreamApiState.INIT,
    )
    return stream
end

"""
    h1_stream_new_request_handler(options::HttpRequestHandlerOptions) -> H1Stream

Create a new server request handler stream.
"""
function h1_stream_new_request_handler(options::HttpRequestHandlerOptions)::H1Stream
    stream = H1Stream(
        options.server_connection,
        UInt32(0),
        1,
        HttpMethod.UNKNOWN,
        HttpStreamMetrics(),
        # callbacks
        options.user_data,
        options.on_request_headers,
        options.on_request_header_block_done,
        options.on_request_body,
        nothing,  # on_metrics
        options.on_complete,
        options.on_destroy,
        # client (unused)
        HTTP_STATUS_CODE_UNKNOWN, UInt64(0),
        # server
        "", "", options.on_request_done,
        false,  # is_client = false (server)
        # thread data
        nothing, false, false, false, false,
        typemax(UInt64),
        false,
        # synced
        H1StreamApiState.INIT,
    )
    return stream
end

# ─── Stream lifecycle ───

function http_stream_acquire(stream::H1Stream)::H1Stream
    @atomic stream.refcount += 1
    return stream
end

function http_stream_release(stream::H1Stream)::Nothing
    old = @atomic stream.refcount
    new_val = old - 1
    @atomic stream.refcount = new_val
    if new_val == 0
        if stream.on_destroy !== nothing
            stream.on_destroy(stream.user_data)
        end
    end
    return nothing
end

http_stream_get_id(stream::H1Stream)::UInt32 = stream.id

function http_stream_get_incoming_response_status(stream::H1Stream)::Int
    return stream.response_status
end

function http_stream_get_connection(stream::H1Stream)
    return stream.owning_connection
end

http_stream_get_incoming_request_method(stream::H1Stream)::String = stream.request_method_str
http_stream_get_incoming_request_uri(stream::H1Stream)::String = stream.request_path

# ─── Stream cancel ───

"""
    http_stream_cancel(stream::H1Stream) -> Nothing

Cancel an in-flight stream. Completes it with ERROR_HTTP_STREAM_CANCELLED.
"""
function http_stream_cancel(stream::H1Stream)::Nothing
    if stream.api_state != H1StreamApiState.COMPLETE
        _stream_complete!(stream, ERROR_HTTP_STREAM_CANCELLED)
    end
    return nothing
end

# ─── Stream window update ───

"""
    http_stream_update_window(stream::H1Stream, increment::UInt64) -> Int

Increment the stream's flow control window by the given amount.
Only valid when manual window management is enabled on the connection.
"""
function http_stream_update_window(stream::H1Stream, increment::UInt64)::Int
    increment == 0 && return raise_error(ERROR_INVALID_ARGUMENT)
    stream.stream_window += increment
    return OP_SUCCESS
end

# ─── Server: send response ───

"""
    h1_stream_send_response!(stream::H1Stream, response::HttpMessage) -> Int

Send a response on a server-side stream. Builds the encoder message
from the response and sets it on the stream for the connection to encode.
"""
function h1_stream_send_response!(stream::H1Stream, response::HttpMessage)::Int
    stream.is_client && return raise_error(ERROR_INVALID_STATE)
    stream.has_outgoing_response && return raise_error(ERROR_INVALID_STATE)

    enc_msg = H1EncoderMessage()
    err = h1_encoder_message_init_from_response!(enc_msg, response)
    err != OP_SUCCESS && return OP_ERR

    stream.encoder_message = enc_msg
    stream.has_outgoing_response = true
    return OP_SUCCESS
end

# ─── Chunked encoding API ───

"""
    h1_stream_write_chunk!(stream::H1Stream, chunk::H1Chunk) -> Int

Submit a chunk to be sent on this stream. The stream's encoder message must
use chunked transfer encoding. A final zero-length chunk terminates the body.
"""
function h1_stream_write_chunk!(stream::H1Stream, chunk::H1Chunk)::Int
    enc = stream.encoder_message
    enc === nothing && return raise_error(ERROR_INVALID_STATE)
    !enc.has_chunked_encoding_header && return raise_error(ERROR_INVALID_STATE)
    push!(enc.pending_chunk_list, chunk)
    return OP_SUCCESS
end

"""
    h1_stream_add_chunked_trailer!(stream::H1Stream, headers::HttpHeaders) -> Int

Set trailing headers on the stream's chunked message. Trailers are sent after
the final zero-length chunk. The headers are pre-encoded into the H1Trailer format.
"""
function h1_stream_add_chunked_trailer!(stream::H1Stream, headers::HttpHeaders)::Int
    enc = stream.encoder_message
    enc === nothing && return raise_error(ERROR_INVALID_STATE)
    !enc.has_chunked_encoding_header && return raise_error(ERROR_INVALID_STATE)
    trailer = h1_trailer_new(headers)
    trailer === nothing && return OP_ERR
    enc.trailer = trailer
    return OP_SUCCESS
end

# ─── Stream completion ───

function _stream_complete!(stream::H1Stream, error_code::Int)::Nothing
    stream.api_state = H1StreamApiState.COMPLETE

    if stream.on_metrics !== nothing
        stream.on_metrics(stream, stream.metrics, stream.user_data)
    end

    if stream.on_complete !== nothing
        stream.on_complete(stream, error_code, stream.user_data)
    end

    # Release the connection's hold on the stream
    http_stream_release(stream)
    return nothing
end
