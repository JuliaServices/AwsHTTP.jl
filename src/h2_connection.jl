# HTTP/2 Connection - Stream management, flow control, settings, GOAWAY, PING
# Port of aws-c-http/source/h2_connection.c, h2_connection.h

# ─── Pending GOAWAY ───

struct H2PendingGoaway
    allow_more_streams::Bool
    http2_error::UInt32
    debug_data::Vector{UInt8}
end

# ─── Pending PING ───

mutable struct H2PendingPing
    opaque_data::Vector{UInt8}  # 8 bytes
    started_time_ns::UInt64
    on_completed::Any  # (rtt_ns, error_code, user_data) -> Nothing
    user_data::Any
end

# ─── Pending settings change ───

mutable struct H2PendingSettings
    settings::Vector{Http2Setting}
    on_completed::Any  # (error_code, user_data) -> Nothing
    user_data::Any
end

# ─── Stream closed reason ───

@enumx H2StreamClosedWhen::UInt8 begin
    UNKNOWN = 0
    BOTH_SIDES_END_STREAM = 1
    RST_STREAM_RECEIVED = 2
    RST_STREAM_SENT = 3
end

# ─── H2 Connection ───

const _H2_PENDING_SETTINGS_MAX = 16
const _H2_MIN_WINDOW_SIZE = 256

mutable struct H2Connection
    # ── Connection identity ──
    http_version::HttpVersion.T
    is_client::Bool
    user_data::Any

    # ── Frame encoder/decoder ──
    encoder::H2FrameEncoder
    decoder::H2Decoder

    # ── Stream management ──
    active_streams::Dict{UInt32, Any}  # stream_id => stream object
    next_stream_id::UInt32             # client=1, server=2; increments by 2
    latest_peer_stream_id::UInt32      # latest stream ID from peer

    # ── Settings (indexed by Http2SettingsId) ──
    settings_local::Dict{Http2SettingsId.T, UInt32}   # our confirmed settings
    settings_remote::Dict{Http2SettingsId.T, UInt32}   # peer's settings
    pending_settings_queue::Vector{H2PendingSettings}  # awaiting ACK

    # ── Flow control (connection level) ──
    window_size_peer::Int64     # peer's send window (reduced by DATA we receive)
    window_size_self::Int64     # our send window (reduced by DATA we send)
    manual_window_management::Bool
    window_size_threshold::UInt32  # threshold to send WINDOW_UPDATE

    # ── GOAWAY state ──
    goaway_sent_last_stream_id::UInt32
    goaway_sent_error_code::UInt32
    goaway_received_last_stream_id::UInt32
    goaway_received_error_code::UInt32
    goaway_sent::Bool
    goaway_received::Bool

    # ── PING state ──
    pending_pings::Vector{H2PendingPing}

    # ── State flags ──
    is_open::Bool
    new_requests_allowed::Bool
    connection_preface_sent::Bool
    connection_preface_received::Bool
    initial_settings_sent::Bool
    has_errored::Bool

    # ── Outgoing frame queue ──
    outgoing_frames::Vector{Vector{UInt8}}      # control frames
    outgoing_high_priority::Vector{Vector{UInt8}}  # high priority (PING ACK, SETTINGS ACK, etc.)

    # ── Callbacks ──
    on_goaway_received::Any    # (last_stream_id, error_code, debug_data) -> Nothing
    on_remote_settings_change::Any  # (settings::Vector{Http2Setting}) -> Nothing
    on_shutdown::Any           # (connection, error_code) -> Nothing
end

# ─── Connection creation ───

function h2_connection_new(;
    is_client::Bool=true,
    user_data=nothing,
    manual_window_management::Bool=false,
    initial_window_size::UInt32=UInt32(H2_INIT_WINDOW_SIZE),
    on_goaway_received=nothing,
    on_remote_settings_change=nothing,
    on_shutdown=nothing,
)::H2Connection

    # Initialize settings to RFC defaults
    settings_local = Dict{Http2SettingsId.T, UInt32}()
    settings_remote = Dict{Http2SettingsId.T, UInt32}()
    for (k, v) in H2_SETTINGS_INITIAL
        settings_local[k] = v
        settings_remote[k] = v
    end

    next_id = is_client ? UInt32(1) : UInt32(2)

    threshold = UInt32(initial_window_size ÷ 2)

    conn = H2Connection(
        HttpVersion.HTTP_2,
        is_client,
        user_data,
        # Encoder/decoder
        h2_frame_encoder_new(),
        h2_decoder_new(is_server=!is_client),
        # Streams
        Dict{UInt32, Any}(),
        next_id,
        UInt32(0),
        # Settings
        settings_local,
        settings_remote,
        H2PendingSettings[],
        # Flow control
        Int64(H2_INIT_WINDOW_SIZE),
        Int64(H2_INIT_WINDOW_SIZE),
        manual_window_management,
        threshold,
        # GOAWAY
        UInt32(H2_STREAM_ID_MAX),
        UInt32(0),
        UInt32(H2_STREAM_ID_MAX),
        UInt32(0),
        false, false,
        # PING
        H2PendingPing[],
        # State
        true, true, false, false, false, false,
        # Outgoing
        Vector{UInt8}[], Vector{UInt8}[],
        # Callbacks
        on_goaway_received,
        on_remote_settings_change,
        on_shutdown,
    )

    return conn
end

# ─── Connection preface ───

"""
    h2_connection_get_preface(conn) -> Vector{UInt8}

Get the connection preface bytes to send. Client: magic string + SETTINGS.
Server: SETTINGS frame only.
"""
function h2_connection_get_preface(conn::H2Connection)::Tuple{Int, Vector{UInt8}}
    output = UInt8[]

    # Client sends magic string first
    if conn.is_client
        append!(output, H2_CONNECTION_PREFACE_CLIENT)
    end

    # Both sides send initial SETTINGS
    initial_settings = Http2Setting[]
    # Send non-default settings
    for (k, v) in conn.settings_local
        if v != H2_SETTINGS_INITIAL[k]
            push!(initial_settings, Http2Setting(k, v))
        end
    end

    status, settings_frame = h2_encode_settings(initial_settings)
    if status != OP_SUCCESS
        return (status, UInt8[])
    end
    append!(output, settings_frame)

    # If automatic window management, send WINDOW_UPDATE to expand connection window
    if !conn.manual_window_management
        extra = UInt32(H2_WINDOW_UPDATE_MAX) - UInt32(H2_INIT_WINDOW_SIZE)
        if extra > 0
            status2, wu_frame = h2_encode_window_update(UInt32(0), extra)
            if status2 == OP_SUCCESS
                append!(output, wu_frame)
                conn.window_size_self = Int64(H2_WINDOW_UPDATE_MAX)
            end
        end
    end

    conn.connection_preface_sent = true
    conn.initial_settings_sent = true
    return (OP_SUCCESS, output)
end

# ─── Settings management ───

"""
    h2_connection_change_settings!(conn, settings, on_completed, user_data) -> Int

Queue a SETTINGS frame to change local settings. The callback is invoked when the
peer acknowledges with SETTINGS ACK.
"""
function h2_connection_change_settings!(conn::H2Connection, settings::Vector{Http2Setting};
    on_completed=nothing, user_data=nothing)::Int

    if !conn.is_open
        return raise_error(ERROR_HTTP_CONNECTION_CLOSED)
    end
    if length(conn.pending_settings_queue) >= _H2_PENDING_SETTINGS_MAX
        return raise_error(ERROR_INVALID_STATE)
    end

    # Validate settings
    for s in settings
        bounds = get(H2_SETTINGS_BOUNDS, s.id, nothing)
        if bounds === nothing
            return raise_error(ERROR_INVALID_ARGUMENT)
        end
        if s.value < bounds[1] || s.value > bounds[2]
            return raise_error(ERROR_INVALID_ARGUMENT)
        end
    end

    # Create and queue pending settings
    pending = H2PendingSettings(copy(settings), on_completed, user_data)
    push!(conn.pending_settings_queue, pending)

    # Encode and queue SETTINGS frame
    status, frame_data = h2_encode_settings(settings)
    if status != OP_SUCCESS
        pop!(conn.pending_settings_queue)
        return status
    end
    push!(conn.outgoing_frames, frame_data)

    return OP_SUCCESS
end

"""
    h2_connection_on_settings_received!(conn, settings) -> H2Err

Handle received SETTINGS frame from peer. Updates remote settings and sends ACK.
"""
function h2_connection_on_settings_received!(conn::H2Connection, settings::Vector{Http2Setting})::H2Err
    # Apply settings
    changed = Http2Setting[]
    for s in settings
        old_val = get(conn.settings_remote, s.id, nothing)
        if old_val === nothing || old_val != s.value
            conn.settings_remote[s.id] = s.value
            push!(changed, s)

            # Apply side effects
            if s.id == Http2SettingsId.HEADER_TABLE_SIZE
                h2_frame_encoder_set_setting_header_table_size!(conn.encoder, s.value)
            elseif s.id == Http2SettingsId.MAX_FRAME_SIZE
                h2_frame_encoder_set_setting_max_frame_size!(conn.encoder, s.value)
            elseif s.id == Http2SettingsId.INITIAL_WINDOW_SIZE
                # Adjust all active stream windows by delta
                if old_val !== nothing
                    delta = Int64(s.value) - Int64(old_val)
                    # TODO: adjust stream windows when streams are implemented
                end
            end
        end
    end

    # Send SETTINGS ACK
    status, ack = h2_encode_settings(Http2Setting[]; ack=true)
    if status == OP_SUCCESS
        push!(conn.outgoing_high_priority, ack)
    end

    # Invoke callback
    if conn.on_remote_settings_change !== nothing && !isempty(changed)
        conn.on_remote_settings_change(changed)
    end

    return H2ERR_SUCCESS
end

"""
    h2_connection_on_settings_ack!(conn) -> H2Err

Handle received SETTINGS ACK. Confirms pending local settings.
"""
function h2_connection_on_settings_ack!(conn::H2Connection)::H2Err
    if isempty(conn.pending_settings_queue)
        return h2err_from_h2_code(Http2ErrorCode.PROTOCOL_ERROR)
    end

    pending = popfirst!(conn.pending_settings_queue)

    # Apply confirmed settings locally
    for s in pending.settings
        old_val = get(conn.settings_local, s.id, nothing)
        conn.settings_local[s.id] = s.value

        # Apply side effects
        if s.id == Http2SettingsId.HEADER_TABLE_SIZE
            h2_decoder_set_setting_header_table_size!(conn.decoder, s.value)
        elseif s.id == Http2SettingsId.MAX_FRAME_SIZE
            h2_decoder_set_setting_max_frame_size!(conn.decoder, s.value)
        end
    end

    # Invoke callback
    if pending.on_completed !== nothing
        pending.on_completed(OP_SUCCESS, pending.user_data)
    end

    return H2ERR_SUCCESS
end

# ─── GOAWAY handling ───

"""
    h2_connection_send_goaway!(conn; allow_more_streams, error_code, debug_data) -> Int

Send a GOAWAY frame. If allow_more_streams, uses MAX_STREAM_ID to allow in-flight streams.
"""
function h2_connection_send_goaway!(conn::H2Connection;
    allow_more_streams::Bool=false,
    error_code::UInt32=UInt32(0),
    debug_data::Vector{UInt8}=UInt8[])::Int

    if !conn.is_open
        return raise_error(ERROR_HTTP_CONNECTION_CLOSED)
    end

    last_stream = if allow_more_streams
        UInt32(H2_STREAM_ID_MAX)
    else
        min(conn.latest_peer_stream_id, conn.goaway_sent_last_stream_id)
    end

    # Can't send higher last_stream_id than previous GOAWAY
    if conn.goaway_sent && last_stream > conn.goaway_sent_last_stream_id
        last_stream = conn.goaway_sent_last_stream_id
    end

    status, frame_data = h2_encode_goaway(last_stream, error_code; debug_data=debug_data)
    if status != OP_SUCCESS
        return status
    end

    push!(conn.outgoing_high_priority, frame_data)
    conn.goaway_sent = true
    conn.goaway_sent_last_stream_id = last_stream
    conn.goaway_sent_error_code = error_code

    if !allow_more_streams
        conn.new_requests_allowed = false
    end

    return OP_SUCCESS
end

"""
    h2_connection_on_goaway_received!(conn, last_stream_id, error_code, debug_data) -> H2Err

Handle received GOAWAY frame from peer.
"""
function h2_connection_on_goaway_received!(conn::H2Connection, last_stream_id::UInt32,
    error_code::UInt32, debug_data::Vector{UInt8})::H2Err

    # last_stream_id must not increase
    if conn.goaway_received && last_stream_id > conn.goaway_received_last_stream_id
        return h2err_from_h2_code(Http2ErrorCode.PROTOCOL_ERROR)
    end

    conn.goaway_received = true
    conn.goaway_received_last_stream_id = last_stream_id
    conn.goaway_received_error_code = error_code
    conn.new_requests_allowed = false

    # Invoke callback
    if conn.on_goaway_received !== nothing
        conn.on_goaway_received(last_stream_id, error_code, debug_data)
    end

    return H2ERR_SUCCESS
end

# ─── PING handling ───

"""
    h2_connection_send_ping!(conn, opaque_data; on_completed, user_data) -> Int

Send a PING frame. on_completed is called when PING ACK is received with RTT in nanoseconds.
"""
function h2_connection_send_ping!(conn::H2Connection,
    opaque_data::Vector{UInt8}=zeros(UInt8, H2_PING_DATA_SIZE);
    on_completed=nothing, user_data=nothing)::Int

    if !conn.is_open
        return raise_error(ERROR_HTTP_CONNECTION_CLOSED)
    end
    if length(opaque_data) != H2_PING_DATA_SIZE
        return raise_error(ERROR_INVALID_ARGUMENT)
    end

    timestamp = time_ns()
    pending = H2PendingPing(copy(opaque_data), UInt64(timestamp), on_completed, user_data)
    push!(conn.pending_pings, pending)

    status, frame_data = h2_encode_ping(opaque_data; ack=false)
    if status != OP_SUCCESS
        pop!(conn.pending_pings)
        return status
    end
    push!(conn.outgoing_frames, frame_data)

    return OP_SUCCESS
end

"""
    h2_connection_on_ping!(conn, opaque_data) -> H2Err

Handle received PING (not ACK). Immediately queues PING ACK response.
"""
function h2_connection_on_ping!(conn::H2Connection, opaque_data::Vector{UInt8})::H2Err
    status, ack_frame = h2_encode_ping(opaque_data; ack=true)
    if status == OP_SUCCESS
        push!(conn.outgoing_high_priority, ack_frame)
    end
    return H2ERR_SUCCESS
end

"""
    h2_connection_on_ping_ack!(conn, opaque_data) -> H2Err

Handle received PING ACK. Matches with pending PING and calculates RTT.
"""
function h2_connection_on_ping_ack!(conn::H2Connection, opaque_data::Vector{UInt8})::H2Err
    if isempty(conn.pending_pings)
        return h2err_from_h2_code(Http2ErrorCode.PROTOCOL_ERROR)
    end

    pending = popfirst!(conn.pending_pings)

    if pending.opaque_data != opaque_data
        return h2err_from_h2_code(Http2ErrorCode.PROTOCOL_ERROR)
    end

    rtt_ns = UInt64(time_ns()) - pending.started_time_ns

    if pending.on_completed !== nothing
        pending.on_completed(rtt_ns, OP_SUCCESS, pending.user_data)
    end

    return H2ERR_SUCCESS
end

# ─── Flow control ───

"""
    h2_connection_update_window!(conn, increment) -> Int

Send a connection-level WINDOW_UPDATE frame.
"""
function h2_connection_update_window!(conn::H2Connection, increment::UInt32)::Int
    if increment == 0 || increment > H2_WINDOW_UPDATE_MAX
        return raise_error(ERROR_INVALID_ARGUMENT)
    end

    # Cap to prevent overflow
    new_window = conn.window_size_self + Int64(increment)
    if new_window > Int64(H2_WINDOW_UPDATE_MAX)
        return raise_error(ERROR_INVALID_ARGUMENT)
    end

    status, frame_data = h2_encode_window_update(UInt32(0), increment)
    if status != OP_SUCCESS
        return status
    end

    conn.window_size_self = new_window
    push!(conn.outgoing_frames, frame_data)
    return OP_SUCCESS
end

# ─── Frame dispatch (decode incoming data) ───

"""
    h2_connection_decode!(conn, data) -> (H2Err, Vector{H2DecodedFrame})

Feed incoming data to the connection's frame decoder. Returns decoded frames.
Handles connection-level frames (SETTINGS, GOAWAY, PING, WINDOW_UPDATE) internally.
Returns stream-level frames (DATA, HEADERS, RST_STREAM, PRIORITY) for the caller.
"""
function h2_connection_decode!(conn::H2Connection, data::AbstractVector{UInt8})::Tuple{H2Err, Vector{H2DecodedFrame}}
    stream_frames = H2DecodedFrame[]
    pos = 1

    while pos <= length(data)
        err, frame, new_pos = h2_decode_frame(conn.decoder, data, pos)

        if h2err_failed(err)
            conn.has_errored = true
            return (err, stream_frames)
        end

        # No progress = need more data
        if new_pos == pos
            break
        end
        pos = new_pos

        # Skip empty/incomplete frames
        if frame.frame_type == H2FrameType.UNKNOWN && frame.stream_id == 0 && frame.flags == 0
            continue
        end

        # Dispatch connection-level frames internally
        dispatch_err = _h2_dispatch_connection_frame!(conn, frame)
        if h2err_failed(dispatch_err)
            conn.has_errored = true
            return (dispatch_err, stream_frames)
        end

        # Pass stream-level frames to caller
        if frame.frame_type in (H2FrameType.DATA, H2FrameType.HEADERS,
            H2FrameType.RST_STREAM, H2FrameType.PRIORITY, H2FrameType.PUSH_PROMISE)
            push!(stream_frames, frame)
        end
    end

    return (H2ERR_SUCCESS, stream_frames)
end

function _h2_dispatch_connection_frame!(conn::H2Connection, frame::H2DecodedFrame)::H2Err
    ft = frame.frame_type

    if ft == H2FrameType.SETTINGS
        if frame.ack
            return h2_connection_on_settings_ack!(conn)
        else
            return h2_connection_on_settings_received!(conn, frame.settings)
        end
    elseif ft == H2FrameType.PING
        if frame.ack
            return h2_connection_on_ping_ack!(conn, frame.opaque_data)
        else
            return h2_connection_on_ping!(conn, frame.opaque_data)
        end
    elseif ft == H2FrameType.GOAWAY
        return h2_connection_on_goaway_received!(conn, frame.last_stream_id,
            frame.goaway_error_code, frame.debug_data)
    elseif ft == H2FrameType.WINDOW_UPDATE && frame.stream_id == 0
        # Connection-level WINDOW_UPDATE
        if frame.window_increment == 0
            return h2err_from_h2_code(Http2ErrorCode.PROTOCOL_ERROR)
        end
        new_window = conn.window_size_peer + Int64(frame.window_increment)
        if new_window > Int64(H2_WINDOW_UPDATE_MAX)
            return h2err_from_h2_code(Http2ErrorCode.FLOW_CONTROL_ERROR)
        end
        conn.window_size_peer = new_window
        return H2ERR_SUCCESS
    end

    return H2ERR_SUCCESS
end

# ─── Outgoing frame collection ───

"""
    h2_connection_get_outgoing_frames!(conn) -> Vector{UInt8}

Collect all queued outgoing frames (high priority first) into a single buffer.
Clears the outgoing queues.
"""
function h2_connection_get_outgoing_frames!(conn::H2Connection)::Vector{UInt8}
    output = UInt8[]

    # High priority first (PING ACK, SETTINGS ACK, RST_STREAM, GOAWAY)
    for frame in conn.outgoing_high_priority
        append!(output, frame)
    end
    empty!(conn.outgoing_high_priority)

    # Normal priority
    for frame in conn.outgoing_frames
        append!(output, frame)
    end
    empty!(conn.outgoing_frames)

    return output
end

# ─── Query functions ───

function h2_connection_get_local_settings(conn::H2Connection)::Dict{Http2SettingsId.T, UInt32}
    return copy(conn.settings_local)
end

function h2_connection_get_remote_settings(conn::H2Connection)::Dict{Http2SettingsId.T, UInt32}
    return copy(conn.settings_remote)
end

function h2_connection_get_sent_goaway(conn::H2Connection)::Tuple{Bool, UInt32, UInt32}
    return (conn.goaway_sent, conn.goaway_sent_last_stream_id, conn.goaway_sent_error_code)
end

function h2_connection_get_received_goaway(conn::H2Connection)::Tuple{Bool, UInt32, UInt32}
    return (conn.goaway_received, conn.goaway_received_last_stream_id, conn.goaway_received_error_code)
end

# ─── Connection interface implementation ───

http_connection_close(conn::H2Connection) = begin
    conn.is_open = false
    conn.new_requests_allowed = false
end

http_connection_is_open(conn::H2Connection) = conn.is_open

http_connection_new_requests_allowed(conn::H2Connection) = conn.new_requests_allowed && conn.is_open

http_connection_is_client(conn::H2Connection) = conn.is_client

http_connection_get_version(conn::H2Connection) = conn.http_version

http_connection_stop_new_requests(conn::H2Connection) = begin conn.new_requests_allowed = false; nothing end
