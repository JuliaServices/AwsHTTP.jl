# AwsHTTP vs aws-c-http Parity Roadmap

Goal: reach functional and behavioral parity with aws-c-http (Jacob's fork with HTTP/2 server/spec compliance extensions) using a pure Julia implementation. This roadmap assumes:

- Pure Julia implementation wherever possible, building on the AwsIO layer already ported.
- Follow all patterns from `PORTING_PATTERNS.md` (no abstract-typed fields, parametric types, `Memory{T}`, no finalizers, `EnumX`, `ScopedValues`, `@atomic`, `ErrorResult`, OS dispatch; function or union fields with parametric union members should also be parameterized).
- AwsIO provides: event loops, channels, channel handlers, sockets, TLS, bootstrap, host resolver, retry, futures, streams, byte buffers, ALPN, message pool, statistics handler, PKCS#11.
- HTTP/1.1 and HTTP/2 both require full client+server support.
- WebSocket requires full client+server support.
- Connection Manager, HTTP/2 Stream Manager, and Proxy support are required.
- For each section/item, complete the implementation, ensure there are tests to cover new code, ensure tests are passing, and commit changes (code and tests).
- No shortcuts, "stubbing out", skipping. Do the full implementation to reach full parity with aws-c-http.
- For clarification scenarios, clearly state assumptions, provide evidence-based recommendations, confirm direction to go for implementation.

## Source reference

C source: `~/aws-c-http` (Jacob's fork with HTTP/2 server extensions)
- 10 public headers in `include/aws/http/`
- 24 private headers in `include/aws/http/private/`
- 28 source files in `source/` (~35,000 lines)
- 36 test files in `tests/` (~44,000 lines)

Legend:
- [ ] Not started
- [~] In progress
- [x] Done

---

## Phase 0: Core library, errors, logging, status codes

**C source**: `http.h`, `http_impl.h`, `http.c`, `status_code.h`
**Estimated items**: ~80 error codes + enums + init/cleanup

### 0.1 Library init/cleanup
- [x] `aws_http_library_init()` / `aws_http_library_clean_up()` equivalents
- [x] Register error codes (range `AWS_C_HTTP_PACKAGE_ID = 2`)
- [x] Register log subjects
- [x] Init HPACK static tables
- [x] Init status code string table
- [x] Idempotent init/cleanup across modules

### 0.2 Error codes (`aws_http_errors`)
Port all ~44 error codes from `http.h`:
- [x] `AWS_ERROR_HTTP_UNKNOWN`
- [x] `AWS_ERROR_HTTP_HEADER_NOT_FOUND`
- [x] `AWS_ERROR_HTTP_INVALID_HEADER_FIELD`
- [x] `AWS_ERROR_HTTP_INVALID_HEADER_NAME`
- [x] `AWS_ERROR_HTTP_INVALID_HEADER_VALUE`
- [x] `AWS_ERROR_HTTP_INVALID_METHOD`
- [x] `AWS_ERROR_HTTP_INVALID_PATH`
- [x] `AWS_ERROR_HTTP_INVALID_STATUS_CODE`
- [x] `AWS_ERROR_HTTP_MISSING_BODY_STREAM`
- [x] `AWS_ERROR_HTTP_INVALID_BODY_STREAM`
- [x] `AWS_ERROR_HTTP_CONNECTION_CLOSED`
- [x] `AWS_ERROR_HTTP_SWITCHED_PROTOCOLS`
- [x] `AWS_ERROR_HTTP_UNSUPPORTED_PROTOCOL`
- [x] `AWS_ERROR_HTTP_REACTION_REQUIRED`
- [x] `AWS_ERROR_HTTP_DATA_NOT_AVAILABLE`
- [x] `AWS_ERROR_HTTP_OUTGOING_STREAM_LENGTH_INCORRECT`
- [x] `AWS_ERROR_HTTP_CALLBACK_FAILURE`
- [x] `AWS_ERROR_HTTP_WEBSOCKET_UPGRADE_FAILURE`
- [x] `AWS_ERROR_HTTP_WEBSOCKET_CLOSE_FRAME_SENT`
- [x] `AWS_ERROR_HTTP_WEBSOCKET_IS_MIDCHANNEL_HANDLER`
- [x] `AWS_ERROR_HTTP_CONNECTION_MANAGER_INVALID_STATE_FOR_ACQUIRE`
- [x] `AWS_ERROR_HTTP_CONNECTION_MANAGER_VENDED_CONNECTION_UNDERFLOW`
- [x] `AWS_ERROR_HTTP_SERVER_CLOSED`
- [x] `AWS_ERROR_HTTP_PROXY_CONNECT_FAILED`
- [x] `AWS_ERROR_HTTP_CONNECTION_MANAGER_SHUTTING_DOWN`
- [x] `AWS_ERROR_HTTP_CHANNEL_THROUGHPUT_FAILURE`
- [x] `AWS_ERROR_HTTP_PROTOCOL_ERROR`
- [x] `AWS_ERROR_HTTP_STREAM_IDS_EXHAUSTED`
- [x] `AWS_ERROR_HTTP_GOAWAY_RECEIVED`
- [x] `AWS_ERROR_HTTP_RST_STREAM_RECEIVED`
- [x] `AWS_ERROR_HTTP_RST_STREAM_SENT`
- [x] `AWS_ERROR_HTTP_STREAM_NOT_ACTIVATED`
- [x] `AWS_ERROR_HTTP_STREAM_HAS_COMPLETED`
- [x] `AWS_ERROR_HTTP_PROXY_STRATEGY_NTLM_CHALLENGE_TOKEN_MISSING`
- [x] `AWS_ERROR_HTTP_PROXY_STRATEGY_TOKEN_RETRIEVAL_FAILURE`
- [x] `AWS_ERROR_HTTP_PROXY_CONNECT_FAILED_RETRYABLE`
- [x] `AWS_ERROR_HTTP_PROTOCOL_SWITCH_FAILURE`
- [x] `AWS_ERROR_HTTP_MAX_CONCURRENT_STREAMS_EXCEEDED`
- [x] `AWS_ERROR_HTTP_STREAM_MANAGER_SHUTTING_DOWN`
- [x] `AWS_ERROR_HTTP_STREAM_MANAGER_CONNECTION_ACQUIRE_FAILURE`
- [x] `AWS_ERROR_HTTP_STREAM_MANAGER_UNEXPECTED_HTTP_VERSION`
- [x] `AWS_ERROR_HTTP_WEBSOCKET_PROTOCOL_ERROR`
- [x] `AWS_ERROR_HTTP_MANUAL_WRITE_NOT_ENABLED`
- [x] `AWS_ERROR_HTTP_MANUAL_WRITE_HAS_COMPLETED`
- [x] `AWS_ERROR_HTTP_RESPONSE_FIRST_BYTE_TIMEOUT`
- [x] `AWS_ERROR_HTTP_CONNECTION_MANAGER_ACQUISITION_TIMEOUT`
- [x] `AWS_ERROR_HTTP_CONNECTION_MANAGER_MAX_PENDING_ACQUISITIONS_EXCEEDED`

### 0.3 HTTP/2 error codes (`aws_http2_error_code`)
- [x] `AWS_HTTP2_ERR_NO_ERROR` (0x00)
- [x] `AWS_HTTP2_ERR_PROTOCOL_ERROR` (0x01)
- [x] `AWS_HTTP2_ERR_INTERNAL_ERROR` (0x02)
- [x] `AWS_HTTP2_ERR_FLOW_CONTROL_ERROR` (0x03)
- [x] `AWS_HTTP2_ERR_SETTINGS_TIMEOUT` (0x04)
- [x] `AWS_HTTP2_ERR_STREAM_CLOSED` (0x05)
- [x] `AWS_HTTP2_ERR_FRAME_SIZE_ERROR` (0x06)
- [x] `AWS_HTTP2_ERR_REFUSED_STREAM` (0x07)
- [x] `AWS_HTTP2_ERR_CANCEL` (0x08)
- [x] `AWS_HTTP2_ERR_COMPRESSION_ERROR` (0x09)
- [x] `AWS_HTTP2_ERR_CONNECT_ERROR` (0x0A)
- [x] `AWS_HTTP2_ERR_ENHANCE_YOUR_CALM` (0x0B)
- [x] `AWS_HTTP2_ERR_INADEQUATE_SECURITY` (0x0C)
- [x] `AWS_HTTP2_ERR_HTTP_1_1_REQUIRED` (0x0D)
- [x] `aws_http2_error_code_to_str()` — string conversion

### 0.4 Log subjects (`aws_http_log_subject`)
- [x] `AWS_LS_HTTP_GENERAL`
- [x] `AWS_LS_HTTP_CONNECTION`
- [x] `AWS_LS_HTTP_ENCODER`
- [x] `AWS_LS_HTTP_DECODER`
- [x] `AWS_LS_HTTP_SERVER`
- [x] `AWS_LS_HTTP_STREAM`
- [x] `AWS_LS_HTTP_CONNECTION_MANAGER`
- [x] `AWS_LS_HTTP_STREAM_MANAGER`
- [x] `AWS_LS_HTTP_WEBSOCKET`
- [x] `AWS_LS_HTTP_WEBSOCKET_SETUP`
- [x] `AWS_LS_HTTP_PROXY_NEGOTIATION`

### 0.5 HTTP version enum
- [x] `AWS_HTTP_VERSION_UNKNOWN`
- [x] `AWS_HTTP_VERSION_1_0`
- [x] `AWS_HTTP_VERSION_1_1`
- [x] `AWS_HTTP_VERSION_2`
- [x] `aws_http_version_to_str()` — string conversion

### 0.6 HTTP status codes (`aws_http_status_code`)
- [x] Port all ~60 status code enum values (100-511)
- [x] `aws_http_status_text()` — returns description string for status code

### 0.7 HTTP method constants
- [x] `aws_http_method_get`, `_head`, `_post`, `_put`, `_delete`, `_connect`, `_options` byte cursors
- [x] `aws_http_method` enum (`UNKNOWN`, `GET`, `HEAD`, `CONNECT`)
- [x] `aws_http_str_to_method()` — case-sensitive method string lookup

### 0.8 HTTP header name constants
- [x] Pseudo-header cursors: `:method`, `:scheme`, `:authority`, `:path`, `:status`
- [x] Scheme cursors: `http`, `https`
- [x] `aws_http_header_name` enum (30+ known header names)
- [x] `aws_http_str_to_header_name()` — case-insensitive lookup
- [x] `aws_http_lowercase_str_to_header_name()` — case-sensitive lookup

### 0.9 Retryable error helper
- [x] `aws_http_error_code_is_retryable()` — classify transient vs permanent errors

### 0.10 Tests
- [x] Port `test_http.c` (library init test)
- [x] Error code registration tests
- [x] Status text lookup tests
- [x] Method/header string conversion tests

---

## Phase 1: HTTP headers and messages

**C source**: `request_response.h`, `request_response_impl.h`, `request_response.c`
**C lines**: ~54,000 bytes source, ~52,000 bytes header
**Key pattern**: P15 (refcounting) for headers/messages, P12 (options structs)

### 1.1 `aws_http_headers` (header collection)
- [x] `aws_http_headers_new()` — create header collection
- [x] `aws_http_headers_acquire()` / `aws_http_headers_release()` — lifecycle (Pattern P15)
- [x] `aws_http_headers_add()` — add name+value
- [x] `aws_http_headers_add_header()` — add from header struct
- [x] `aws_http_headers_add_array()` — add array of headers
- [x] `aws_http_headers_set()` — set (add + remove existing with same name)
- [x] `aws_http_headers_count()` — total count
- [x] `aws_http_headers_get_index()` — get header at index
- [x] `aws_http_headers_get()` — get first value by name
- [x] `aws_http_headers_get_all()` — get all values comma-separated
- [x] `aws_http_headers_has()` — test if name exists
- [x] `aws_http_headers_erase()` — remove all by name
- [x] `aws_http_headers_erase_value()` — remove specific name+value pair
- [x] `aws_http_headers_erase_index()` — remove at index
- [x] `aws_http_headers_clear()` — remove all
- [x] `aws_http_header_name_eq()` — case-insensitive name comparison

### 1.2 HTTP/2 pseudo-header accessors
- [x] `aws_http2_headers_get_request_method()` / `set_request_method()`
- [x] `aws_http2_headers_get_request_scheme()` / `set_request_scheme()`
- [x] `aws_http2_headers_get_request_authority()` / `set_request_authority()`
- [x] `aws_http2_headers_get_request_path()` / `set_request_path()`
- [x] `aws_http2_headers_get_response_status()` / `set_response_status()`

### 1.3 `aws_http_header` struct
- [x] `name` (byte cursor), `value` (byte cursor), `compression` (enum)
- [x] `aws_http_header_compression` enum: `USE_CACHE`, `NO_CACHE`, `NO_FORWARD_CACHE`
- [x] `aws_http_header_block` enum: `MAIN`, `INFORMATIONAL`, `TRAILING`

### 1.4 `aws_http_message` (request/response)
- [x] `aws_http_message_new_request()` — create blank HTTP/1.1 request
- [x] `aws_http_message_new_request_with_headers()` — with existing headers
- [x] `aws_http_message_new_response()` — create blank HTTP/1.1 response
- [x] `aws_http2_message_new_request()` — create blank HTTP/2 request
- [x] `aws_http2_message_new_response()` — create blank HTTP/2 response
- [x] `aws_http2_message_new_from_http1()` — convert H1 request to H2
- [x] `aws_http2_message_new_from_http1_with_scheme()` — same with scheme override
- [x] `aws_http_message_acquire()` / `aws_http_message_release()` — lifecycle
- [x] `aws_http_message_is_request()` / `aws_http_message_is_response()`
- [x] `aws_http_message_get_protocol_version()`
- [x] `aws_http_message_get_request_method()` / `set_request_method()`
- [x] `aws_http_message_get_request_path()` / `set_request_path()`
- [x] `aws_http_message_get_response_status()` / `set_response_status()`
- [x] `aws_http_message_get_body_stream()` / `set_body_stream()`
- [x] `aws_http_message_get_headers()` / `get_const_headers()`
- [x] `aws_http_message_get_header_count()` / `get_header()` / `add_header()` / `add_header_array()`
- [x] `aws_http_message_erase_header()`

### 1.5 `aws_http2_priority_settings`
- [x] `stream_dependency` (UInt32), `stream_dependency_exclusive` (Bool), `weight` (UInt16: 1-256)

### 1.6 `aws_http_stream_metrics`
- [x] `send_start_timestamp_ns`, `send_end_timestamp_ns`, `sending_duration_ns`
- [x] `receive_start_timestamp_ns`, `receive_end_timestamp_ns`, `receiving_duration_ns`
- [x] `stream_id`

### 1.7 Tests
- [x] Port `test_message.c` (34,454 bytes, comprehensive header/message tests)
  - [x] Header creation, add, get, set, erase, clear
  - [x] Header ordering guarantees
  - [x] Request/response message creation
  - [x] H2 pseudo-header accessors
  - [x] H1→H2 message conversion
  - [x] Body stream handling

---

## Phase 2: HTTP/1.1 encoder

**C source**: `h1_encoder.h`, `h1_encoder.c`
**C lines**: ~43,424 bytes source, ~5,190 bytes header
**Key pattern**: State machine encoder, chunked transfer encoding

### 2.1 Encoder state machine
- [x] `aws_h1_encoder` struct with state, progress_bytes, current_chunk, message pointer
- [x] `aws_h1_encoder_state` enum (11 states):
  - [x] `INIT`, `HEAD`
  - [x] `UNCHUNKED_BODY_STREAM` — stream body with known Content-Length
  - [x] `CHUNKED_BODY_STREAM` — stream body with chunked encoding (unknown length)
  - [x] `CHUNKED_BODY_STREAM_LAST_CHUNK`
  - [x] `CHUNK_NEXT`, `CHUNK_LINE`, `CHUNK_BODY`, `CHUNK_END`, `CHUNK_TRAILER`
  - [x] `DONE`
- [x] `aws_h1_encoder_init()` / `aws_h1_encoder_clean_up()`
- [x] `aws_h1_encoder_start_message()` — begin encoding a message
- [x] `aws_h1_encoder_process()` — write encoded bytes to output buffer
- [x] `aws_h1_encoder_is_message_in_progress()` — query state
- [x] `aws_h1_encoder_is_waiting_for_chunks()` — query if stalled on chunk data

### 2.2 Encoder message (`aws_h1_encoder_message`)
- [x] `aws_h1_encoder_message_init_from_request()` — validate + cache request data
- [x] `aws_h1_encoder_message_init_from_response()` — validate + cache response data
- [x] `aws_h1_encoder_message_clean_up()`
- [x] `outgoing_head_buf` — pre-encoded request/status line + headers
- [x] `body` — input stream for unchunked body
- [x] `pending_chunk_list` — linked list of `aws_h1_chunk` for chunked encoding
- [x] `content_length`, `has_connection_close_header`, `has_chunked_encoding_header`

### 2.3 Chunk and trailer support
- [x] `aws_h1_chunk` struct: allocator, data stream, data_size, on_complete callback, chunk_line buffer
- [x] `aws_h1_chunk_new()` from `aws_http1_chunk_options`
- [x] `aws_h1_chunk_destroy()` / `aws_h1_chunk_complete_and_destroy()`
- [x] `aws_http1_chunk_extension` struct: key + value cursors
- [x] `aws_http1_chunk_options` struct: chunk_data, chunk_data_size, extensions, on_complete
- [x] `aws_h1_trailer` struct: allocator, trailer_data buffer
- [x] `aws_h1_trailer_new()` / `aws_h1_trailer_destroy()`

### 2.4 Request line encoding
- [x] `METHOD SP PATH SP HTTP/1.1 CRLF` format
- [x] Validation: method must be non-empty, path must be non-empty

### 2.5 Response line encoding
- [x] `HTTP/1.1 SP STATUS SP REASON CRLF` format
- [x] Validation: status code range

### 2.6 Header encoding
- [x] `Name: Value CRLF` for each header
- [x] Empty line `CRLF` after headers
- [x] Transfer-Encoding: chunked detection and handling
- [x] Content-Length detection
- [x] Connection: close detection

### 2.7 Tests
- [x] Port `test_h1_encoder.c` (~17,921 bytes)
  - [x] Request encoding (GET, POST, HEAD, etc.)
  - [x] Response encoding
  - [x] Body encoding (with Content-Length)
  - [x] Chunked encoding
  - [x] Chunk extensions
  - [x] Trailer encoding
  - [x] Error cases (invalid headers, missing body, etc.)
  - [x] Fragmented output buffer (encoder resumes)

---

## Phase 3: HTTP/1.1 decoder

**C source**: `h1_decoder.h`, `h1_decoder.c`
**C lines**: ~30,317 bytes source, ~3,430 bytes header
**Key pattern**: State machine decoder with vtable callbacks

### 3.1 Decoder vtable
- [x] `on_header(decoded_header, user_data)` — called for each decoded header
- [x] `on_body(data, finished, user_data)` — called for body chunks
- [x] `on_request(method_enum, method_str, uri, user_data)` — request line
- [x] `on_response(status_code, user_data)` — response status line
- [x] `on_done(user_data)` — message complete

### 3.2 Decoder state machine
- [x] `aws_h1_decoder` — opaque decoder struct
- [x] `aws_h1_decoder_params` — init options (alloc, scratch_space_initial_size, is_decoding_requests, user_data, vtable)
- [x] `aws_h1_decoder_new()` / `aws_h1_decoder_destroy()`
- [x] `aws_h1_decode()` — feed data, callbacks fire as parsing completes
- [x] `aws_h1_decoder_set_logging_id()`
- [x] `aws_h1_decoder_set_body_headers_ignored()` — for HEAD responses

### 3.3 Transfer encoding detection
- [x] `aws_h1_decoder_get_encoding_flags()` — bitflags for chunked/gzip/deflate/compress
- [x] `aws_h1_decoder_get_content_length()`
- [x] `aws_h1_decoder_get_body_headers_ignored()`
- [x] `aws_h1_decoder_get_header_block()` — MAIN/INFORMATIONAL/TRAILING

### 3.4 `aws_h1_decoded_header` struct
- [x] `name` (enum aws_http_header_name)
- [x] `name_data` (raw cursor)
- [x] `value_data` (raw cursor)
- [x] `data` (entire header line cursor)

### 3.5 Request line parsing
- [x] Parse `METHOD SP URI SP HTTP/VERSION CRLF`
- [x] Method string to enum mapping
- [x] HTTP version validation (1.0 and 1.1)

### 3.6 Response line parsing
- [x] Parse `HTTP/VERSION SP STATUS SP REASON CRLF`
- [x] Status code extraction
- [x] Informational (1xx) vs final response handling

### 3.7 Header parsing
- [x] Parse `Name: Value CRLF` with folding
- [x] Header name to known-enum fast lookup
- [x] Detect Content-Length, Transfer-Encoding, Connection
- [x] Trailing headers after chunked body

### 3.8 Body parsing
- [x] Content-Length body: read exactly N bytes
- [x] Chunked body: parse chunk-size, extensions, data, trailer
- [ ] Connection-close body: read until EOF
- [x] No body (HEAD responses, 204/304 responses)

### 3.9 Tests
- [x] Port `test_h1_decoder.c` (~37,912 bytes)
  - [x] Request line parsing
  - [x] Response line parsing (including 1xx informational)
  - [x] Header parsing (various edge cases)
  - [x] Content-Length body
  - [x] Chunked body + chunk extensions + trailers
  - [ ] Connection-close body
  - [x] Incremental feeding (partial data)
  - [x] Error cases (malformed requests, invalid headers)
  - [x] Transfer-Encoding detection
  - [x] HEAD response (body headers ignored)

---

## Phase 4: HTTP/1.1 connection

**C source**: `h1_connection.h`, `h1_connection.c`, `connection.c`, `connection_impl.h`
**C lines**: ~130,072 bytes h1_connection.c, ~52,393 bytes connection.c
**Key pattern**: Channel handler vtable (Pattern P1), state machine

### 4.1 Connection vtable (`aws_http_connection_vtable`)
- [x] `channel_handler_vtable` — embedded channel handler vtable
- [ ] `on_channel_handler_installed` — post-install callback
- [x] `make_request` — create client stream
- [ ] `new_server_request_handler_stream` — create server request handler
- [ ] `stream_send_response` — send response on server stream
- [x] `close` — initiate shutdown
- [x] `stop_new_requests` — stop accepting new requests
- [x] `is_open` — query open state
- [x] `new_requests_allowed` — query if new requests possible

### 4.2 Base `aws_http_connection` struct
- [x] `vtable`, `channel_handler`, `channel_slot`, `alloc`
- [x] `http_version`, `is_using_tls`
- [ ] `proxy_request_transform` callback
- [x] `user_data`
- [ ] `refcount` (atomic) — Pattern P15
- [x] `next_stream_id` — starts at 1 (client) or 2 (server), increments by 2
- [x] `client_or_server_data` union — client timeout vs server callbacks
- [x] `stream_manual_window_management`

### 4.3 HTTP/1.1 connection specifics (`aws_h1_connection`)
- [x] Thread data (encoder, decoder, current streams, pending write)
- [x] Stream outgoing queue (synced + thread-only)
- [ ] Read buffer and flow control
- [ ] Waiting-for-chunks state
- [x] Pipeline behavior (sequential request/response on same connection)
- [x] Connection: close handling
- [ ] Switching protocols (101 response)
- [ ] Response first-byte timeout tracking

### 4.4 Connection public API
- [ ] `aws_http_client_connect()` — async connect with options
- [ ] `aws_http_connection_release()` — release user hold
- [x] `aws_http_connection_close()` — begin shutdown
- [x] `aws_http_connection_stop_new_requests()` — prevent new requests
- [x] `aws_http_connection_is_open()`
- [x] `aws_http_connection_new_requests_allowed()`
- [x] `aws_http_connection_is_client()` / `is_server()`
- [x] `aws_http_connection_get_version()`
- [ ] `aws_http_connection_get_channel()`
- [ ] `aws_http_connection_get_remote_endpoint()`

### 4.5 Connection options structs
- [x] `aws_http_client_connection_options` — full client options
  - [ ] `self_size`, `allocator`, `bootstrap`, `host_name`, `port`
  - [ ] `socket_options`, `tls_options`, `proxy_options`, `proxy_ev_settings`
  - [x] `monitoring_options`, `response_first_byte_timeout_ms`
  - [x] `manual_window_management`, `initial_window_size`
  - [x] `user_data`, `on_setup`, `on_shutdown`
  - [ ] `prior_knowledge_http2`, `h2c_upgrade`
  - [ ] `alpn_string_map`, `http1_options`, `http2_options`
  - [ ] `requested_event_loop`, `host_resolution_config`
- [x] `aws_http1_connection_options` — H1-specific (read_buffer_capacity)
- [x] `aws_http_connection_monitoring_options` — throughput monitoring

### 4.6 ALPN string map
- [ ] `aws_http_alpn_map_init()` / `aws_http_alpn_map_init_copy()` — string→version mapping
- [ ] Default mapping: "h2"→HTTP_2, "http/1.1"→HTTP_1_1

### 4.7 Client bootstrap integration
- [ ] `aws_http_client_bootstrap` struct — manages async connect
- [ ] Channel handler creation based on ALPN negotiation result
- [ ] `aws_http_connection_new_channel_handler()` — create connection on channel
- [ ] Prior knowledge HTTP/2 (cleartext) support
- [ ] h2c upgrade support

### 4.8 H1 connection channel handler
- [x] `process_read_message` — feed data to decoder
- [x] `process_write_message` — feed data to encoder
- [x] `increment_read_window` — flow control
- [x] `shutdown` — connection shutdown sequencing
- [x] `initial_window_size` / `message_overhead` / `destroy`

### 4.9 H1 connection write path
- [x] Stream outgoing queue management (synced cross-thread)
- [x] Encoder drives write of current stream
- [x] Pipeline: next stream starts encoding after current completes
- [ ] Waiting-for-chunks state (chunked encoding without all data upfront)
- [ ] Write completion callbacks

### 4.10 H1 connection read path
- [x] Decoder feeds incoming data
- [x] Stream callbacks: on_headers, on_header_block_done, on_body, on_complete
- [ ] Informational (1xx) response handling
- [ ] Flow control / read back-pressure
- [ ] Read buffer capacity management

### 4.11 Tests
- [x] Port `test_connection.c` (~61,055 bytes)
  - [x] Client connection setup/shutdown
  - [x] Server connection setup/shutdown
  - [ ] ALPN negotiation
  - [ ] Prior knowledge HTTP/2
  - [ ] h2c upgrade
  - [x] Connection version detection
  - [x] Error cases
- [x] Port `test_h1_client.c` (~233,245 bytes — largest test file)
  - [x] Basic GET/POST requests
  - [x] Request with body (Content-Length)
  - [ ] Request with chunked body
  - [x] Multiple requests on same connection (pipelining)
  - [x] Response parsing (headers, body, status)
  - [ ] Informational (1xx) responses
  - [ ] Manual window management / flow control
  - [x] Connection close handling
  - [ ] Switching protocols (101)
  - [ ] Response first-byte timeout
  - [ ] Stream metrics
  - [x] Error conditions
  - [ ] Trailer support
- [ ] Port `test_h1_server.c` (~95,188 bytes)
  - [ ] Incoming request parsing
  - [ ] Response sending
  - [ ] Server-side chunked encoding
  - [ ] Multiple sequential requests
  - [ ] Server shutdown with active streams
  - [ ] Error conditions

---

## Phase 5: HTTP/1.1 streams

**C source**: `h1_stream.h`, `h1_stream.c`, `request_response_impl.h`
**C lines**: ~27,837 bytes h1_stream.c, ~5,723 bytes header

### 5.1 H1 stream struct
- [x] Base fields: connection, user_data, callbacks, stream_id, refcount
- [x] Client stream: outgoing request message, incoming response status
- [x] Server stream: incoming request (method, URI), outgoing response message
- [x] Encoder message (cached request/response data for encoder)
- [ ] Pending chunk list for chunked encoding
- [x] Stream state machine (WAITING, ACTIVE, COMPLETE)
- [x] Metrics tracking (send/receive timestamps)

### 5.2 Client stream API
- [x] `aws_http_connection_make_request()` — create stream from request options
- [x] `aws_http_stream_activate()` — start sending
- [x] `aws_http_stream_acquire()` / `aws_http_stream_release()` — lifecycle
- [x] `aws_http_stream_get_connection()`
- [x] `aws_http_stream_get_incoming_response_status()`
- [x] `aws_http_stream_get_id()`
- [ ] `aws_http_stream_cancel()` — cancel in-flight stream
- [ ] `aws_http_stream_update_window()` — increment flow-control window

### 5.3 Server stream API
- [x] `aws_http_stream_new_server_request_handler()` — create from handler options
- [ ] `aws_http_stream_send_response()` — send response
- [x] `aws_http_stream_get_incoming_request_method()` / `get_incoming_request_uri()`

### 5.4 Chunked encoding (H1)
- [ ] `aws_http1_stream_write_chunk()` — submit chunk data
- [ ] `aws_http1_chunk_options` — chunk data + extensions + on_complete
- [ ] `aws_http1_chunk_extension` — key+value
- [ ] Final zero-length chunk terminates stream
- [ ] `aws_http1_stream_add_chunked_trailer()` — add trailing headers

### 5.5 Callback types
- [x] `aws_http_on_incoming_headers_fn` — header array callback
- [x] `aws_http_on_incoming_header_block_done_fn` — header block complete
- [x] `aws_http_on_incoming_body_fn` — body data callback
- [x] `aws_http_on_incoming_request_done_fn` — request done (server only)
- [x] `aws_http_on_stream_complete_fn` — stream complete (success or error)
- [x] `aws_http_on_stream_destroy_fn` — stream fully destroyed
- [x] `aws_http_on_stream_metrics_fn` — metrics before completion

### 5.6 Request/response options structs
- [x] `aws_http_make_request_options` — client request options
  - [x] `request`, `user_data`, `on_response_headers`, `on_response_header_block_done`
  - [x] `on_response_body`, `on_metrics`, `on_complete`, `on_destroy`
  - [ ] `http2_use_manual_data_writes`, `http2_priority`, `http2_headers_pad_length`
  - [ ] `h2c_upgrade`, `on_h2c_upgrade`
  - [x] `response_first_byte_timeout_ms`
- [x] `aws_http_request_handler_options` — server handler options
  - [x] `server_connection`, `user_data`, `on_request_headers`, `on_request_header_block_done`
  - [x] `on_request_body`, `on_request_done`, `on_complete`, `on_destroy`

### 5.7 Tests
- [x] Stream lifecycle tests (covered by Phase 4 connection tests)
- [ ] Flow control / window management tests
- [ ] Stream cancellation tests
- [ ] Metrics tests

---

## Phase 6: HPACK (HTTP/2 header compression)

**C source**: `hpack.h`, `hpack.c`, `hpack_encoder.c`, `hpack_decoder.c`, `hpack_huffman_static.c`
**C lines**: ~20,224 bytes hpack.c, ~21,373 bytes decoder, ~17,425 bytes encoder, ~52,880 bytes huffman
**Key pattern**: State machine decoder, static + dynamic table, Huffman coding (RFC 7541)

### 6.1 HPACK context (shared table)
- [x] `aws_hpack_context` struct: allocator, dynamic table (ring buffer), reverse lookup
- [x] `aws_hpack_context_init()` / `aws_hpack_context_clean_up()`
- [x] `aws_hpack_get_header_size()` — name.len + value.len + 32 (RFC 7541 section 4.1)
- [x] `aws_hpack_get_dynamic_table_num_elements()`
- [x] `aws_hpack_get_dynamic_table_max_size()`
- [x] `aws_hpack_get_header()` — get entry by index (static + dynamic)
- [x] `aws_hpack_find_index()` — reverse lookup (value match vs name-only)
- [x] `aws_hpack_insert_header()` — add to dynamic table (evicts oldest if needed)
- [x] `aws_hpack_resize_dynamic_table()` — change max size

### 6.2 Static table
- [x] 61-entry static table from RFC 7541 Appendix A
- [x] `hpack_header_static_table.def` — static table definitions
- [x] `aws_hpack_static_table_init()` / `aws_hpack_static_table_clean_up()`

### 6.3 HPACK encoder
- [x] `aws_hpack_encoder` struct: context, huffman encoder, size update tracking
- [x] `aws_hpack_encoder_init()` / `aws_hpack_encoder_clean_up()`
- [x] `aws_hpack_encoder_set_max_table_size()` — set encoder table size
- [x] `aws_hpack_encoder_update_max_table_size()` — signal new SETTINGS value
- [x] `aws_hpack_encoder_set_huffman_mode()` — SMALLEST/NEVER/ALWAYS
- [x] `aws_hpack_encode_header_block()` — encode full header block
- [x] `aws_hpack_encode_integer()` — encode HPACK integer (variable prefix)
- [x] `aws_hpack_encode_string()` — encode string (optional Huffman)

### 6.4 HPACK decoder
- [x] `aws_hpack_decoder` struct: context, huffman decoder, state machine progress
- [x] `aws_hpack_decoder_init()` / `aws_hpack_decoder_clean_up()`
- [x] `aws_hpack_decoder_update_max_table_size()` — signal new SETTINGS
- [x] `aws_hpack_decoder_set_max_string_length()` — cap decoded string size
- [x] `aws_hpack_decode()` — decode next entry from cursor
- [x] `aws_hpack_decode_integer()` — decode HPACK integer
- [x] `aws_hpack_decode_string()` — decode HPACK string
- [x] Decoder state machine:
  - [x] Entry states: INIT, INDEXED, LITERAL_BEGIN, LITERAL_NAME_STRING, LITERAL_VALUE_STRING, DYNAMIC_TABLE_RESIZE, COMPLETE
  - [x] Integer states: INIT, VALUE
  - [x] String states: INIT, LENGTH, VALUE

### 6.5 `aws_hpack_decode_result`
- [x] `type`: ONGOING, HEADER_FIELD, DYNAMIC_TABLE_RESIZE
- [x] Union: header_field (aws_http_header) or dynamic_table_resize (size)

### 6.6 Huffman coding
- [x] Static Huffman table from RFC 7541 Appendix B
- [x] `hpack_huffman_static_table.def` — 256 symbol codes + EOS
- [x] Huffman encoder (bit-level encoding)
- [x] Huffman decoder (bit-level decoding with prefix table)
- [x] NOTE: depends on `aws/compression/huffman.h` — may need to port or wrap

### 6.7 Tests
- [x] Port `test_hpack.c` (~43,069 bytes)
  - [x] Integer encode/decode (various prefix sizes)
  - [x] String encode/decode (literal + Huffman)
  - [x] Static table lookup
  - [x] Dynamic table insert/eviction/resize
  - [x] Indexed header field encode/decode
  - [x] Literal header field (with indexing, without indexing, never indexed)
  - [x] Dynamic table size update
  - [x] RFC 7541 examples (C.1 through C.6)
  - [x] Error cases (invalid integer, table overflow)
- [x] Port `test_h2_headers.c` (~35,167 bytes)
  - [x] Header block encoding/decoding roundtrip
  - [x] Pseudo-header ordering
  - [x] Header compression modes
  - [x] Large headers
  - [x] Dynamic table interactions

---

## Phase 7: HTTP/2 frames

**C source**: `h2_frames.h`, `h2_frames.c`, `h2_decoder.h`, `h2_decoder.c`
**C lines**: ~51,972 bytes frames source, ~92,998 bytes decoder source
**Key pattern**: Frame encoder with vtable, state machine decoder

### 7.1 Frame types (`aws_h2_frame_type`)
- [x] `DATA` (0x00), `HEADERS` (0x01), `PRIORITY` (0x02), `RST_STREAM` (0x03)
- [x] `SETTINGS` (0x04), `PUSH_PROMISE` (0x05), `PING` (0x06), `GOAWAY` (0x07)
- [x] `WINDOW_UPDATE` (0x08), `CONTINUATION` (0x09), `UNKNOWN`
- [x] `aws_h2_frame_type_to_str()` — string conversion

### 7.2 Frame flags (`aws_h2_frame_flag`)
- [x] `ACK` (0x01), `END_STREAM` (0x01), `END_HEADERS` (0x04), `PADDED` (0x08), `PRIORITY` (0x20)

### 7.3 Frame constants
- [x] `AWS_H2_PAYLOAD_MAX` (0x00FFFFFF — 3 bytes)
- [x] `AWS_H2_WINDOW_UPDATE_MAX` (0x7FFFFFFF)
- [x] `AWS_H2_STREAM_ID_MAX` (0x7FFFFFFF)
- [x] `AWS_H2_FRAME_PREFIX_SIZE` (9)
- [x] `AWS_H2_INIT_WINDOW_SIZE` (65535)
- [x] Connection preface client string

### 7.4 H2 error handling (`aws_h2err`)
- [x] `aws_h2err` struct: h2_code + aws_code
- [x] `aws_h2err_from_h2_code()` — create from HTTP/2 error code
- [x] `aws_h2err_from_aws_code()` — create from AWS error code
- [x] `aws_h2err_from_last_error()`
- [x] `aws_h2err_success()` / `aws_h2err_failed()`
- [x] `aws_h2_validate_stream_id()`

### 7.5 Frame encoder (`aws_h2_frame_encoder`)
- [x] `aws_h2_frame_encoder` struct: allocator, hpack encoder, current_frame, settings
- [x] `aws_h2_frame_encoder_init()` / `aws_h2_frame_encoder_clean_up()`
- [x] `aws_h2_encode_frame()` — encode frame to buffer (may need multiple calls)
- [x] `aws_h2_encode_data_frame()` — encode DATA frame from input stream
- [x] `aws_h2_frame_encoder_set_setting_header_table_size()`
- [x] `aws_h2_frame_encoder_set_setting_max_frame_size()`

### 7.6 Frame constructors
- [x] `aws_h2_frame_new_headers()` — HEADERS (may produce CONTINUATION frames)
- [x] `aws_h2_frame_new_priority()` — PRIORITY
- [x] `aws_h2_frame_new_rst_stream()` — RST_STREAM
- [x] `aws_h2_frame_new_settings()` — SETTINGS (with ack flag)
- [x] `aws_h2_frame_new_push_promise()` — PUSH_PROMISE (may produce CONTINUATION)
- [x] `aws_h2_frame_new_ping()` — PING (with ack and opaque data)
- [x] `aws_h2_frame_new_goaway()` — GOAWAY (last_stream_id, error, debug_data)
- [x] `aws_h2_frame_new_window_update()` — WINDOW_UPDATE
- [x] `aws_h2_frame_destroy()`

### 7.7 Frame vtable
- [x] `aws_h2_frame_vtable`: destroy + encode function pointers
- [x] `aws_h2_frame` base: vtable, alloc, node, type, stream_id, high_priority

### 7.8 Settings support
- [x] `aws_h2_settings_bounds` — min/max per setting
- [x] `aws_h2_settings_initial` — default values (RFC 7540 6.5.2)
- [x] `aws_http2_settings_id` enum: HEADER_TABLE_SIZE, ENABLE_PUSH, MAX_CONCURRENT_STREAMS, INITIAL_WINDOW_SIZE, MAX_FRAME_SIZE, MAX_HEADER_LIST_SIZE
- [x] `aws_h2_encode_http2_settings_header()` — encode for Upgrade header
- [x] `aws_h2_decode_http2_settings_header()` — decode from Upgrade header

### 7.9 Priority settings
- [x] `aws_h2_frame_priority_settings` struct: stream_dependency, exclusive, weight

### 7.10 H2 decoder (`aws_h2_decoder`)
- [x] Frame decoder state machine
- [x] `aws_h2_decoder` struct: state, header accumulator, current frame info
- [x] Decoder vtable callbacks (one per frame type received)
- [x] Frame prefix parsing (9-byte header: length, type, flags, stream_id)
- [x] Padding handling for PADDED frames
- [x] CONTINUATION frame merging into HEADERS/PUSH_PROMISE
- [x] Settings validation (bounds checking)
- [x] Flow control validation

### 7.11 Tests
- [x] Port `test_h2_encoder.c` (~24,563 bytes)
  - [x] Each frame type encoding
  - [x] HEADERS with CONTINUATION
  - [x] DATA frame encoding from stream
  - [x] Settings encoding/decoding
  - [x] Padding
  - [x] Error cases
- [x] Port `test_h2_decoder.c` (~186,472 bytes — second largest test file)
  - [x] Each frame type decoding
  - [x] Connection preface
  - [x] CONTINUATION reassembly
  - [x] Padding validation
  - [x] Settings validation
  - [x] Flow control validation
  - [x] Stream ID validation
  - [x] Error protocol violations
  - [x] Incremental feeding

---

## Phase 8: HTTP/2 connection

**C source**: `h2_connection.h`, `h2_connection.c`
**C lines**: ~181,762 bytes source (largest file), ~14,901 bytes header
**Key pattern**: Channel handler, stream management, flow control, GOAWAY/SETTINGS/PING state machines

### 8.1 H2 connection struct
- [x] Base `aws_http_connection` fields
- [x] Frame encoder + decoder
- [x] Stream table (active streams by ID)
- [x] Recently-closed stream tracking
- [x] Local + remote settings (6 settings each)
- [x] Connection-level flow control (send/receive windows)
- [x] GOAWAY state (sent + received)
- [x] PING tracking (outstanding pings, RTT)
- [x] Outgoing frame queue (high priority + normal)
- [x] Thread synced data for cross-thread operations

### 8.2 H2 connection vtable implementation
- [x] `make_request()` — create H2 client stream
- [x] `new_server_request_handler_stream()` — create H2 server stream
- [x] `stream_send_response()` — send H2 response
- [x] `close()` / `stop_new_requests()` / `is_open()` / `new_requests_allowed()`
- [x] `update_window()` — connection-level WINDOW_UPDATE
- [x] `change_settings()` — send SETTINGS frame
- [x] `send_ping()` — send PING frame
- [x] `send_goaway()` — send GOAWAY frame
- [x] `get_sent_goaway()` / `get_received_goaway()`
- [x] `get_local_settings()` / `get_remote_settings()`

### 8.3 Connection preface
- [x] Client sends: magic string + SETTINGS frame
- [x] Server receives and validates magic string
- [x] Server sends: SETTINGS frame
- [x] Both sides acknowledge with SETTINGS ACK

### 8.4 Settings management
- [x] Track local pending vs confirmed settings
- [x] Track remote settings
- [x] SETTINGS ACK handling
- [x] `on_initial_settings_completed` callback
- [x] `on_remote_settings_change` callback
- [x] Dynamic table size updates propagated to HPACK

### 8.5 GOAWAY handling
- [x] Graceful shutdown: send GOAWAY with MAX_STREAM_ID, then final GOAWAY
- [x] `on_goaway_received` callback
- [x] Track last stream IDs (local + remote)
- [x] Reject streams above last_stream_id after GOAWAY

### 8.6 Flow control
- [x] Connection-level window (send + receive)
- [x] WINDOW_UPDATE frame sending/receiving
- [x] Automatic window management (when manual is false)
- [x] Manual window management with thresholds
  - [x] `conn_window_size_threshold_to_send_update`
  - [x] `stream_window_size_threshold_to_send_update`
- [x] Padding counts toward flow control

### 8.7 Frame dispatch (read path)
- [x] DATA → route to stream
- [x] HEADERS → route to stream (or create server stream)
- [x] PRIORITY → update dependency (informational)
- [x] RST_STREAM → complete stream with error
- [x] SETTINGS → apply settings
- [x] PUSH_PROMISE → invoke callback or reject
- [x] PING → auto-respond with PING ACK
- [x] GOAWAY → record and invoke callback
- [x] WINDOW_UPDATE → update send window
- [x] CONTINUATION → append to current HEADERS/PUSH_PROMISE
- [x] Unknown frame types → ignore

### 8.8 Frame dispatch (write path)
- [x] High-priority queue (PING ACK, SETTINGS ACK, RST_STREAM, GOAWAY)
- [x] Normal queue (HEADERS, DATA, PUSH_PROMISE, WINDOW_UPDATE, PRIORITY)
- [x] DATA frame scheduling across streams (round-robin with flow control)
- [x] MAX_FRAME_SIZE enforcement

### 8.9 Connection-specific HTTP/2 public API
- [x] `aws_http2_connection_change_settings()` — change local settings
- [x] `aws_http2_connection_ping()` — send PING, measure RTT
- [x] `aws_http2_connection_get_local_settings()` / `get_remote_settings()`
- [x] `aws_http2_connection_send_goaway()` — send custom GOAWAY
- [x] `aws_http2_connection_get_sent_goaway()` / `get_received_goaway()`
- [x] `aws_http2_connection_update_window()` — connection-level window

### 8.10 Tests
- [x] Port `test_h2_client.c` (~411,150 bytes — largest test file overall)
  - [x] Connection preface exchange
  - [x] Settings negotiation
  - [x] Basic request/response
  - [x] Multiple concurrent streams
  - [x] Stream priority
  - [x] Flow control (connection + stream level)
  - [x] Manual window management
  - [x] GOAWAY handling (graceful + error)
  - [x] PING / RTT measurement
  - [x] MAX_CONCURRENT_STREAMS enforcement
  - [x] RST_STREAM
  - [x] Push promise (client receiving)
  - [x] Connection error conditions
  - [x] Protocol violations
  - [x] Header compression edge cases
  - [x] Trailing headers
  - [x] Manual data writes
  - [x] Response first-byte timeout
  - [x] Stream metrics
- [x] Port `test_h2_server.c` (~39,407 bytes)
  - [x] Server connection preface
  - [x] Incoming request handling
  - [x] Response sending
  - [x] Push promise (server sending)
  - [x] Multiple concurrent streams
  - [x] GOAWAY from server
  - [x] Server-side flow control
  - [x] Server-side error conditions

---

## Phase 9: HTTP/2 streams

**C source**: `h2_stream.h`, `h2_stream.c`
**C lines**: ~97,857 bytes source, ~11,524 bytes header
**Key pattern**: Stream state machine, flow control window per stream

### 9.1 H2 stream struct
- [x] Base stream fields (connection, user_data, callbacks, stream_id, refcount)
- [x] Stream state machine (IDLE, OPEN, HALF_CLOSED_LOCAL, HALF_CLOSED_REMOTE, CLOSED)
- [x] Send/receive window sizes
- [x] Outgoing frame queue
- [x] Manual data write tracking
- [x] Headers sent/received state
- [x] END_STREAM sent/received tracking
- [x] RST_STREAM sent/received tracking
- [x] Priority settings
- [x] Metrics (timestamps)

### 9.2 Client stream creation
- [x] Create from `aws_http_make_request_options`
- [x] H1→H2 message conversion (if H1 message on H2 connection)
- [x] Stream ID assignment (odd numbers for client)
- [x] Priority encoding in HEADERS frame

### 9.3 Server stream creation
- [x] Created when HEADERS frame received
- [x] Stream ID validation (even numbers for server-initiated)
- [x] `aws_http_stream_new_server_request_handler()` from handler options

### 9.4 Manual data writes (H2)
- [x] `aws_http2_stream_write_data()` — submit DATA for stream
- [x] `aws_http2_stream_write_data_with_options()` — v2 with padding
- [x] `aws_http2_stream_write_data_options` struct: data stream, end_stream, on_complete
- [x] `aws_http2_stream_write_data_options_v2` struct: adds pad_length

### 9.5 Trailing headers (H2)
- [x] `aws_http2_stream_add_trailing_headers()` — add trailers
- [x] `aws_http2_stream_add_trailing_headers_with_options()` — with padding
- [x] Trailers sent in HEADERS frame after final DATA

### 9.6 Push promise
- [x] `aws_http2_stream_new_push_promise()` — client accepts pushed stream
- [x] `aws_http2_stream_send_push_promise()` — server sends PUSH_PROMISE
- [x] `aws_http2_send_push_promise_options` struct
- [x] `aws_http_on_incoming_push_promise_fn` callback

### 9.7 Stream-level operations
- [x] `aws_http_stream_activate()` — begin sending
- [x] `aws_http_stream_update_window()` — stream flow control
- [x] `aws_http_stream_cancel()` — cancel (sends RST_STREAM with CANCEL)
- [x] `aws_http2_stream_reset()` — send RST_STREAM with custom error
- [x] `aws_http2_stream_update_priority()` — send PRIORITY frame
- [x] `aws_http2_stream_get_received_reset_error_code()` — query RST received
- [x] `aws_http2_stream_get_sent_reset_error_code()` — query RST sent

### 9.8 Stream state transitions
- [x] Sending HEADERS → OPEN (or HALF_CLOSED_LOCAL if END_STREAM)
- [x] Receiving HEADERS → OPEN (or HALF_CLOSED_REMOTE if END_STREAM)
- [x] Sending END_STREAM → transition to HALF_CLOSED_LOCAL or CLOSED
- [x] Receiving END_STREAM → transition to HALF_CLOSED_REMOTE or CLOSED
- [x] RST_STREAM → CLOSED
- [x] Stream error → send RST_STREAM, CLOSED

### 9.9 Server response sending (H2)
- [x] `aws_http2_stream_send_response()` — with padding options
- [x] `aws_http_stream_send_response()` — generic (works for H1 and H2)

### 9.10 h2c upgrade
- [x] `aws_http_h2c_upgrade_mode` enum: DEFAULT, ENABLE, DISABLE
- [x] `aws_http_on_h2c_upgrade_fn` callback
- [x] Server-side h2c upgrade handling

### 9.11 Tests
- [x] Covered by Phase 8 connection tests (h2_client, h2_server)
- [x] Stream-specific edge cases in flow control
- [x] Manual write tests
- [x] Trailing header tests
- [x] Push promise tests
- [x] Stream reset tests
- [x] Priority tests

---

## Phase 10: HTTP server

**C source**: `server.h`, `connection.c` (server portions)
**C lines**: ~7,343 bytes header
**Key pattern**: Listener + connection factory

### 10.1 `aws_http_server` struct
- [x] Listener socket wrapping `aws_server_bootstrap`
- [x] Incoming connection handling
- [x] Server lifecycle (new, release, destroy callback)

### 10.2 Server options
- [x] `aws_http_server_options`:
  - [x] `allocator`, `bootstrap`, `endpoint`, `socket_options`
  - [x] `tls_options`, `prior_knowledge_http2`
  - [x] `initial_window_size`, `manual_window_management`
  - [x] `server_user_data`, `on_incoming_connection`, `on_destroy_complete`

### 10.3 Server connection configuration
- [x] `aws_http_server_connection_options`:
  - [x] `connection_user_data`, `on_incoming_request`, `on_h2c_upgrade`, `on_shutdown`
- [x] `aws_http_connection_configure_server()` — must be called from on_incoming_connection

### 10.4 Server API
- [x] `aws_http_server_new()` — create listener
- [x] `aws_http_server_release()` — shut down
- [x] `aws_http_connection_is_server()`
- [x] `aws_http_server_get_listener_endpoint()`

### 10.5 Callback types
- [x] `aws_http_server_on_incoming_connection_fn`
- [x] `aws_http_server_on_destroy_fn`
- [x] `aws_http_on_incoming_request_fn`
- [x] `aws_http_on_server_h2c_upgrade_request_fn`
- [x] `aws_http_on_server_connection_shutdown_fn`

### 10.6 Tests
- [x] Covered by h1_server and h2_server tests in Phase 4 and Phase 8

---

## Phase 11: WebSocket

**C source**: `websocket.h`, `websocket_impl.h`, `websocket.c`, `websocket_encoder.h`, `websocket_encoder.c`, `websocket_decoder.h`, `websocket_decoder.c`, `websocket_bootstrap.c`
**C lines**: ~95,818 bytes websocket.c, ~37,452 bytes bootstrap, ~19,273 bytes decoder, ~14,499 bytes encoder
**Key pattern**: Channel handler, frame encoder/decoder, handshake via HTTP upgrade

### 11.1 WebSocket opcodes (`aws_websocket_opcode`)
- [x] `CONTINUATION` (0x0), `TEXT` (0x1), `BINARY` (0x2)
- [x] `CLOSE` (0x8), `PING` (0x9), `PONG` (0xA)
- [x] `aws_websocket_is_data_frame()` — classify data vs control

### 11.2 WebSocket encoder
- [x] Frame header encoding: FIN, RSV, opcode, MASK, payload length
- [x] 7-bit length / 16-bit extended / 64-bit extended length encoding
- [x] Masking key generation (client frames must be masked)
- [x] Payload masking XOR operation
- [x] Encoder state machine

### 11.3 WebSocket decoder
- [x] Frame header decoding
- [x] Payload length decoding (7/16/64 bit)
- [x] Masking key reading
- [x] Payload unmasking
- [x] Decoder state machine
- [x] Validation (control frame size <=125, RSV bits zero)
- [x] Fragmentation tracking (continuation frames)
- [x] Message length limit enforcement

### 11.4 WebSocket handler (channel handler)
- [x] `aws_websocket` struct — channel handler that implements the WebSocket protocol
- [x] Incoming frame state machine:
  - [x] `on_incoming_frame_begin` callback
  - [x] `on_incoming_frame_payload` callback
  - [x] `on_incoming_frame_complete` callback
- [x] Outgoing frame queue
- [x] Close handshake state machine:
  - [x] Client/server CLOSE frame exchange
  - [x] Close timeout handling
  - [x] Automatic PONG responses to PING
- [x] Auto-PING (periodic PING frames)
- [x] Read window management (manual/automatic)
- [x] Mid-channel handler conversion

### 11.5 Client connection (`aws_websocket_client_connect`)
- [x] `aws_websocket_client_connection_options`:
  - [x] `allocator`, `bootstrap`, `socket_options`, `tls_options`, `proxy_options`
  - [x] `host`, `port`, `handshake_request`
  - [x] `initial_window_size`, `max_incoming_payload_length`, `ping_interval_ms`
  - [x] `user_data`, `on_connection_setup`, `on_connection_shutdown`
  - [x] `on_incoming_frame_begin`, `on_incoming_frame_payload`, `on_incoming_frame_complete`
  - [x] `manual_window_management`, `requested_event_loop`, `host_resolution_config`
- [x] `aws_websocket_on_connection_setup_data` struct
- [x] HTTP upgrade request creation and validation

### 11.6 Server upgrade (`aws_websocket_upgrade`)
- [x] `aws_websocket_server_upgrade_options`:
  - [x] `initial_window_size`, `max_incoming_payload_length`, `ping_interval_ms`
  - [x] `user_data`, frame callbacks, `manual_window_management`
  - [x] `sec_websocket_key`, `response_header_array`, `num_response_headers`
- [x] `aws_websocket_upgrade()` — upgrade HTTP connection to WebSocket

### 11.7 WebSocket public API
- [x] `aws_websocket_acquire()` / `aws_websocket_release()` — lifecycle
- [x] `aws_websocket_close()` — close (optionally immediate)
- [x] `aws_websocket_close_with_reason()` — close with status code + reason
- [x] `aws_websocket_send_frame()` — send raw frame with streaming callback
- [x] `aws_websocket_send_text()` — send TEXT message
- [x] `aws_websocket_send_binary()` — send BINARY message
- [x] `aws_websocket_send_ping()` — send PING
- [x] `aws_websocket_send_pong()` — send PONG
- [x] `aws_websocket_increment_read_window()` — flow control
- [x] `aws_websocket_convert_to_midchannel_handler()` — become channel handler
- [x] `aws_websocket_get_channel()`

### 11.8 Handshake helpers
- [x] `aws_websocket_random_handshake_key()` — generate Sec-WebSocket-Key
- [x] `aws_http_message_new_websocket_handshake_request()` — create upgrade request
- [x] `aws_http_message_new_websocket_handshake_response()` — create upgrade response
- [x] `aws_websocket_is_websocket_request()` — validate upgrade request
- [x] `aws_websocket_get_request_sec_websocket_key()` — extract key from request
- [x] `aws_websocket_select_subprotocol()` — negotiate subprotocol

### 11.9 Send options structs
- [x] `aws_websocket_send_frame_options`: payload_length, stream callback, on_complete, opcode, fin
- [x] `aws_websocket_send_message_options`: payload cursor, on_complete

### 11.10 Tests
- [x] Port `test_websocket_encoder.c` (~21,067 bytes)
  - [x] Frame encoding (all opcodes)
  - [x] Masked frames (client)
  - [x] Unmasked frames (server)
  - [x] Various payload lengths (0, 125, 126, 65535, 65536+)
  - [x] FIN flag handling
- [x] Port `test_websocket_decoder.c` (~36,463 bytes)
  - [x] Frame decoding (all opcodes)
  - [x] Masked/unmasked frames
  - [x] Payload length variations
  - [x] Fragmentation (continuation frames)
  - [x] Control frame size validation
  - [x] Message length limit
  - [x] Incremental feeding
  - [x] Error cases
- [x] Port `test_websocket_handler.c` (~89,055 bytes)
  - [x] Client WebSocket lifecycle
  - [x] Server WebSocket lifecycle
  - [x] Send/receive frames
  - [x] Close handshake (both directions)
  - [x] Auto-PONG
  - [x] Auto-PING
  - [x] Manual window management
  - [x] Mid-channel handler conversion
  - [x] Error conditions
- [x] Port `test_websocket_bootstrap.c` (~55,272 bytes)
  - [x] Client connect (cleartext + TLS)
  - [x] Handshake validation
  - [x] Failed handshake handling
  - [x] Proxy support
  - [x] Server upgrade path
  - [x] Subprotocol negotiation

---

## Phase 12: Connection Manager

**C source**: `connection_manager.h`, `connection_manager.c`, `connection_manager_system_vtable.h`
**C lines**: ~74,310 bytes source, ~9,058 bytes header
**Key pattern**: Connection pool with acquire/release, idle timeout, health monitoring

### 12.1 Connection manager struct
- [x] Pool of HTTP connections to a single endpoint
- [x] Connection lifecycle tracking (idle, vended, connecting)
- [x] Max connections enforcement
- [x] Idle connection timeout
- [x] Acquisition timeout
- [x] Max pending acquisitions
- [x] Network interface distribution (round-robin across interfaces)

### 12.2 Manager options (`aws_http_connection_manager_options`)
- [x] `bootstrap`, `initial_window_size`, `socket_options`
- [x] `response_first_byte_timeout_ms`, `tls_connection_options`
- [x] `http2_prior_knowledge`, `monitoring_options`
- [x] `host`, `port`
- [x] H2-specific: `initial_settings_array`, `num_initial_settings`, `max_closed_streams`, `http2_conn_manual_window_management`
- [x] `proxy_options`, `proxy_ev_settings`
- [x] `max_connections`, `shutdown_complete_user_data`, `shutdown_complete_callback`
- [x] `enable_read_back_pressure`
- [x] `max_connection_idle_in_milliseconds`
- [x] `connection_acquisition_timeout_ms`
- [x] `max_pending_connection_acquisitions`
- [x] `network_interface_names_array`, `num_network_interface_names`

### 12.3 Manager API
- [x] `aws_http_connection_manager_new()` — create manager
- [x] `aws_http_connection_manager_acquire()` / `release()` — refcount
- [x] `aws_http_connection_manager_acquire_connection()` — get connection from pool
- [x] `aws_http_connection_manager_release_connection()` — return to pool
- [x] `aws_http_connection_manager_fetch_metrics()` — get pool stats

### 12.4 Metrics (`aws_http_manager_metrics`)
- [x] `available_concurrency` — idle connections or available streams
- [x] `pending_concurrency_acquires` — waiting requests
- [x] `leased_concurrency` — vended connections/streams

### 12.5 System vtable (for testing)
- [x] `aws_http_connection_manager_system_vtable` — mock points for connection creation

### 12.6 Tests
- [x] Port `test_connection_manager.c` (~83,879 bytes)
  - [x] Basic acquire/release
  - [x] Pool growth up to max_connections
  - [x] Idle connection reuse
  - [x] Idle connection culling
  - [x] Acquisition timeout
  - [x] Max pending acquisitions
  - [x] Connection failure handling
  - [x] Shutdown with active connections
  - [x] Concurrent acquisitions
  - [x] Health monitoring integration
  - [x] Network interface distribution

---

## Phase 13: HTTP/2 Stream Manager

**C source**: `http2_stream_manager.h`, `http2_stream_manager_impl.h`, `http2_stream_manager.c`
**C lines**: ~59,873 bytes source, ~8,700 bytes header + ~8,394 bytes impl header
**Key pattern**: Manages H2 connections + stream multiplexing, builds on Connection Manager

### 13.1 Stream manager struct
- [ ] Pool of HTTP/2 connections with stream multiplexing
- [ ] Ideal/max concurrent streams per connection
- [ ] Connection creation when streams needed
- [ ] PING-based connection health monitoring
- [ ] Connection reuse across stream requests
- [ ] Close connection on 5xx server error

### 13.2 Manager options (`aws_http2_stream_manager_options`)
- [ ] `bootstrap`, `socket_options`, `tls_connection_options`
- [ ] `http2_prior_knowledge`, `host`, `port`
- [ ] H2 settings: `initial_settings_array`, `num_initial_settings`, `max_closed_streams`, `conn_manual_window_management`
- [ ] `enable_read_back_pressure`, `initial_window_size`
- [ ] `monitoring_options`, `proxy_options`, `proxy_ev_settings`
- [ ] `shutdown_complete_user_data`, `shutdown_complete_callback`
- [ ] `close_connection_on_server_error`
- [ ] `connection_ping_period_ms`, `connection_ping_timeout_ms`
- [ ] `ideal_concurrent_streams_per_connection`
- [ ] `max_concurrent_streams_per_connection`
- [ ] `max_connections`

### 13.3 Stream acquisition
- [ ] `aws_http2_stream_manager_acquire_stream()` — async acquire
- [ ] `aws_http2_stream_manager_acquire_stream_options`: callback, user_data, request options
- [ ] `aws_http2_stream_manager_on_stream_acquired_fn` callback

### 13.4 Manager API
- [ ] `aws_http2_stream_manager_new()` — create
- [ ] `aws_http2_stream_manager_acquire()` / `release()` — refcount
- [ ] `aws_http2_stream_manager_fetch_metrics()` — get stats

### 13.5 Tests
- [ ] Port `test_stream_manager.c` (~67,658 bytes)
  - [ ] Basic stream acquisition
  - [ ] Multiple concurrent streams
  - [ ] Connection scaling
  - [ ] Max concurrent streams enforcement
  - [ ] Connection reuse
  - [ ] PING keepalive
  - [ ] Connection failure recovery
  - [ ] 5xx close behavior
  - [ ] Shutdown with active streams
  - [ ] Metrics

---

## Phase 14: Proxy support

**C source**: `proxy.h`, `proxy_impl.h`, `proxy_connection.c`, `proxy_strategy.c`, `no_proxy.c`
**C lines**: ~65,877 bytes proxy_connection, ~64,431 bytes proxy_strategy, ~11,249 bytes no_proxy
**Key pattern**: Strategy pattern (P1/P2), vtable-based negotiation

### 14.1 Proxy types
- [ ] `aws_http_proxy_connection_type`: `HTTP_LEGACY`, `HTTP_FORWARD`, `HTTP_TUNNEL`
- [ ] `aws_http_proxy_authentication_type`: `NONE`, `BASIC` (deprecated)
- [ ] `aws_http_proxy_env_var_type`: `DISABLE`, `ENABLE`

### 14.2 Proxy options (`aws_http_proxy_options`)
- [ ] `connection_type`, `host`, `port`
- [ ] `tls_options` (for proxy connection itself)
- [ ] `proxy_strategy`
- [ ] `auth_type`, `auth_username`, `auth_password` (deprecated)
- [ ] `no_proxy_hosts`

### 14.3 Proxy strategy (`aws_http_proxy_strategy`)
- [ ] `aws_http_proxy_strategy` struct: ref_count, vtable, impl, proxy_connection_type
- [ ] `aws_http_proxy_strategy_vtable`: `create_negotiator`
- [ ] `aws_http_proxy_strategy_acquire()` / `release()`
- [ ] `aws_http_proxy_strategy_create_negotiator()`

### 14.4 Proxy negotiator (`aws_http_proxy_negotiator`)
- [ ] `aws_http_proxy_negotiator` struct: ref_count, impl, strategy vtable union
- [ ] Forwarding vtable: `forward_request_transform`
- [ ] Tunnelling vtable: `connect_request_transform`, `on_incoming_headers`, `on_status`, `on_incoming_body`, `get_retry_directive`
- [ ] `aws_http_proxy_negotiator_acquire()` / `release()`
- [ ] Retry directive: `STOP`, `NEW_CONNECTION`, `CURRENT_CONNECTION`

### 14.5 Built-in strategies
- [ ] `aws_http_proxy_strategy_new_basic_auth()` — basic authentication
- [ ] `aws_http_proxy_strategy_new_tunneling_adaptive()` — kerberos + NTLM adaptive
- [ ] Kerberos options: `get_token`, `get_token_user_data`
- [ ] NTLM options: `get_token`, `get_challenge_token`, `get_challenge_token_user_data`
- [ ] Sequence strategy: chain multiple strategies

### 14.6 Proxy config (persistent options)
- [ ] `aws_http_proxy_config_new_from_connection_options()`
- [ ] `aws_http_proxy_config_new_from_manager_options()`
- [ ] `aws_http_proxy_config_new_tunneling_from_proxy_options()`
- [ ] `aws_http_proxy_config_new_from_proxy_options()`
- [ ] `aws_http_proxy_config_new_from_proxy_options_with_tls_info()`
- [ ] `aws_http_proxy_config_new_clone()`
- [ ] `aws_http_proxy_config_destroy()`
- [ ] `aws_http_proxy_options_init_from_config()`

### 14.7 Proxy socket channel
- [ ] `aws_http_proxy_new_socket_channel()` — establish tunneled connection
- [ ] Integration with connection bootstrap

### 14.8 Environment variable proxy
- [ ] `proxy_env_var_settings` struct
- [ ] `HTTP_PROXY`/`http_proxy`, `HTTPS_PROXY`/`https_proxy`, `NO_PROXY`/`no_proxy`
- [ ] `aws_http_host_matches_no_proxy()` — pattern matching

### 14.9 No-proxy matching
- [ ] Comma-separated host patterns
- [ ] Domain suffix matching
- [ ] IP address matching
- [ ] Wildcard support

### 14.10 Tests
- [ ] Port `test_proxy.c` (~44,499 bytes)
  - [ ] Forward proxy
  - [ ] Tunnel proxy
  - [ ] Basic auth
  - [ ] Kerberos/NTLM adaptive
  - [ ] Proxy config creation/cloning
  - [ ] Error cases
- [ ] Port `test_no_proxy.c` (~17,804 bytes)
  - [ ] Host matching patterns
  - [ ] IP address matching
  - [ ] Wildcard matching
  - [ ] Edge cases

---

## Phase 15: Connection Monitor + Statistics

**C source**: `connection_monitor.h`, `connection_monitor.c`, `statistics.h`, `statistics.c`
**C lines**: ~8,500 bytes monitor, ~1,136 bytes statistics
**Key pattern**: Statistics handler (from AwsIO), throughput monitoring

### 15.1 Connection monitor
- [ ] Throughput tracking (bytes per second, read + write independently)
- [ ] Configurable minimum throughput threshold
- [ ] Allowable failure interval
- [ ] Automatic connection close when unhealthy
- [ ] Integration with channel statistics handler

### 15.2 HTTP statistics
- [ ] `aws_crt_statistics_http1_channel`: pending stream milliseconds, stream IDs
- [ ] `aws_crt_statistics_http2_channel`: pending stream ms, was_inactive flag
- [ ] `aws_crt_statistics_http1_channel_init()` / `cleanup()` / `reset()`
- [ ] `aws_crt_statistics_http2_channel_init()` / `reset()`

### 15.3 Statistics observer
- [ ] `aws_http_statistics_observer_fn` callback
- [ ] Integration with `aws_http_connection_monitoring_options`

### 15.4 Tests
- [ ] Port `test_connection_monitor.c` (~51,960 bytes)
  - [ ] Throughput monitoring
  - [ ] Unhealthy connection detection
  - [ ] Statistics reporting
  - [ ] Observer callback

---

## Phase 16: Utility modules

**C source**: `strutil.h`, `strutil.c`, `random_access_set.h`, `random_access_set.c`
**C lines**: ~10,019 bytes strutil, ~6,768 bytes random_access_set

### 16.1 String utilities (`strutil`)
- [ ] `aws_strutil_is_http_token()` — validate HTTP token characters
- [ ] `aws_strutil_is_http_field_value()` — validate header value
- [ ] `aws_strutil_is_http_request_target()` — validate request path
- [ ] `aws_strutil_is_http_pseudo_header_name()` — check for `:` prefix
- [ ] `aws_strutil_trim_http_whitespace()` — trim OWS from header values
- [ ] `aws_strutil_is_uppercase_http_method()` — validate method case
- [ ] `aws_strutil_is_lowercase_http_header_name()` — validate H2 lowercase

### 16.2 Random access set
- [ ] `aws_random_access_set` — O(1) random access + O(1) removal data structure
- [ ] Used for connection manager internal bookkeeping
- [ ] `init()`, `clean_up()`, `add()`, `remove()`, `random()`, `size()`

### 16.3 Tests
- [ ] Port `test_strutil.c` (~12,847 bytes)
  - [ ] Token validation
  - [ ] Field value validation
  - [ ] Request target validation
  - [ ] Whitespace trimming
- [ ] Port `test_random_access_set.c` (~8,488 bytes)
  - [ ] Add/remove/random access
  - [ ] Edge cases

---

## Phase 17: Integration + localhost tests

**C source**: `test_connection.c`, `test_localhost_integ.c`, `test_tls.c`
**C lines**: ~22,305 bytes localhost, ~13,914 bytes tls

### 17.1 Localhost integration tests
- [ ] Full HTTP/1.1 client-server round-trip over localhost
- [ ] Full HTTP/2 client-server round-trip over localhost
- [ ] TLS integration (requires AwsIO TLS layer)
- [ ] Proxy integration
- [ ] WebSocket integration

### 17.2 TLS-specific tests
- [ ] HTTP over TLS connection setup
- [ ] ALPN negotiation (h2 vs http/1.1)
- [ ] Certificate validation

### 17.3 Tests
- [ ] Port `test_localhost_integ.c` (~22,305 bytes)
- [ ] Port `test_tls.c` (~13,914 bytes)

---

## Phase 18: Test infrastructure

**C source**: `h2_test_helper.h`, `h2_test_helper.c`, `stream_test_helper.h`, `stream_test_helper.c`, `proxy_test_helper.h`, `proxy_test_helper.c`

### 18.1 H2 test helper
- [ ] Mock HTTP/2 peer (encodes/decodes frames without real connection)
- [ ] Simulated connection for unit testing
- [ ] Frame comparison helpers

### 18.2 Stream test helper
- [ ] Mock input/output streams for testing
- [ ] Configurable behavior (blocking, errors, etc.)

### 18.3 Proxy test helper
- [ ] Mock proxy server
- [ ] Configurable proxy behavior

---

## Porting guidelines (from PORTING_PATTERNS.md)

Functions and types should generally remove the `aws_` prefix and adopt more "Julia"n names (i.e. aws_http_connection -> HttpConnection).

The following patterns from the AwsIO port apply directly to AwsHTTP:

| C pattern | Julia pattern | Where used in AwsHTTP |
|-----------|--------------|----------------------|
| P1: Vtables | Abstract types + dispatch | Connection vtable, frame vtable, proxy strategy/negotiator |
| P2: Impl sub-vtables | Subtype methods | H1 vs H2 connection, forwarding vs tunneling negotiator |
| P3: Callback + user_data | Parametric callable fields | All callback options structs |
| P5: ByteBuffer/ByteCursor | Memory{UInt8} + ByteCursor | Header storage, frame encoding/decoding, HPACK |
| P6: Intrusive containers | Index-based linked lists | Stream queues, frame queues, chunk lists |
| P7: Manual containers | Memory{T}-based containers | Header array, dynamic table, settings arrays |
| P8: Opaque handles | Explicit init/destroy | Connections, streams, managers, WebSocket |
| P9: Tagged enums | @enumx scoped enums | Error codes, frame types, opcodes, settings IDs |
| P10: Errors | ErrorResult sentinel | All fallible operations |
| P12: Options structs | @kwdef parametric structs | Connection options, request options, manager options |
| P15: Refcounting | @atomic count + on_zero | Headers, messages, connections, streams, managers |
| P16: Atomics | @atomic fields | Connection refcount, manager state |

### Additional patterns specific to AwsHTTP:

1. **State machines**: H1 encoder/decoder, H2 decoder, WebSocket encoder/decoder, connection state, stream state — use enum-based state with if-else chains.

2. **Channel handler pattern**: HTTP connections are channel handlers from AwsIO. The vtable-based dispatch maps to Julia abstract type dispatch on `AbstractHttpConnection` with subtypes `H1Connection` and `H2Connection`.

3. **Stream multiplexing (H2)**: Multiple concurrent streams per connection with individual flow control windows. Use `Dict{UInt32, H2Stream}` for stream table lookup.

4. **Frame encoding/decoding**: Binary protocol with variable-length fields. Use `IOBuffer` or direct `Memory{UInt8}` manipulation with explicit offset tracking.

5. **HPACK dynamic table**: Ring buffer with reverse lookup. Port as a dedicated struct with `Memory{HttpHeader}` + `Dict` for reverse lookup.

---

## Acceptance criteria

### Per-phase criteria
- [ ] All structs/enums from C headers have Julia equivalents
- [ ] All public API functions have Julia equivalents
- [ ] All state machines produce identical behavior
- [ ] All error conditions produce correct error codes
- [ ] All callback invocations happen on correct thread (event loop)
- [ ] Flow control behavior matches C implementation
- [ ] Tests pass for all ported test cases

### Overall criteria
- [ ] HTTP/1.1 client can make requests and receive responses
- [ ] HTTP/1.1 server can receive requests and send responses
- [ ] HTTP/2 client can make requests with multiplexing
- [ ] HTTP/2 server can handle concurrent streams
- [ ] WebSocket client can connect and exchange frames
- [ ] WebSocket server can accept and exchange frames
- [ ] Connection Manager pools and reuses connections
- [ ] HTTP/2 Stream Manager manages multiplexed streams
- [ ] Proxy forwarding and tunneling work
- [ ] All tests pass

---

## Work phases (recommended order)

### Chunk 1: Foundation (Phases 0-1)
Core types, error codes, headers, messages. No networking yet. Pure data structure work.

### Chunk 2: HTTP/1.1 codec (Phases 2-3)
Encoder and decoder state machines. Can be tested with synthetic data (no real connections).

### Chunk 3: HTTP/1.1 connection + streams (Phases 4-5)
Wire up codec to channel handler. Full H1 client+server with AwsIO channel integration.

### Chunk 4: HPACK + H2 frames (Phases 6-7)
HPACK compression and HTTP/2 frame codec. Can be tested with synthetic data.

### Chunk 5: HTTP/2 connection + streams (Phases 8-9)
Full H2 client+server with multiplexing, flow control, GOAWAY/SETTINGS/PING.

### Chunk 6: HTTP server (Phase 10)
Server listener + connection factory. Integrates with both H1 and H2.

### Chunk 7: WebSocket (Phase 11)
WebSocket codec + handler + bootstrap. Full client+server support.

### Chunk 8: Connection management (Phases 12-13)
Connection Manager and HTTP/2 Stream Manager. Pool management, health monitoring.

### Chunk 9: Proxy + monitor + utilities (Phases 14-16)
Proxy forwarding/tunneling, connection monitoring, string utilities.

### Chunk 10: Integration (Phases 17-18)
End-to-end integration tests, test infrastructure.
