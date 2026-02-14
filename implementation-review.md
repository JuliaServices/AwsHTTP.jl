# AwsHTTP Implementation Review

## Scope
- Julia repo: `/Users/jacob.quinn/.julia/dev/AwsHTTP` (branch `main`)
- Reference C repo: `/Users/jacob.quinn/aws-c-http` @ `1c55fa7` (h1-client host header test)
- This review assumes `AwsIO` provides the IO/event-loop and TLS substrate.

## Executive Summary (High-Impact Divergences)
1. **String-based HPACK/H1 parsing**: Julia implementations frequently convert to `String` (UTF‑8). C uses raw byte cursors. This can reject non‑UTF8 inputs and changes allocation and zero‑copy behavior.
2. **Allocator/refcount semantics absent**: The C API’s explicit allocator/lifetime model is not mirrored; GC-managed objects replace `aws_allocator` + refcount behavior.
3. **Concurrency model differs**: C’s threading and atomic assumptions map to Julia tasks and `@atomic` fields. Ordering/throughput differences may appear in stream scheduling and connection manager timeouts.

## Detailed Review

### Core (`http.jl`, `request_response.jl`, `strutil.jl`)
- Error codes and log subjects are faithfully redefined, but error handling often throws instead of returning `AWS_OP_ERR`.
- `HttpHeader`/`HttpHeaders` are backed by `String` values rather than byte cursors, changing encoding expectations.
- `strutil.jl` uses Julia string utilities; behavior on invalid UTF‑8 bytes differs from C (which treats headers as opaque bytes).

### HTTP/1.1
- `h1_decoder.jl` and `h1_encoder.jl` follow the C state machine structure, but:
  - They parse into `String` and validate by iterating `codeunits(String)`.
  - This is stricter than C for non‑UTF8 payloads and may throw on malformed inputs where C would produce `AWS_ERROR_HTTP_PROTOCOL_ERROR`.
  - Header/value storage is not zero‑copy; C uses cursor slices into scratch space.
- `h1_connection.jl`/`h1_stream.jl`:
  - Stream activation and encoder flushing are task-driven; ordering may differ from C’s event-loop timing.
  - Manual write and chunked body handling mirror C’s control flow but rely on Julia IO buffers.

### HTTP/2 Core
- `h2_frames.jl`:
  - Frame encoding/decoding uses `Vector{UInt8}` and `String` for header data. C uses raw byte buffers and explicit `aws_byte_cursor`.
  - Verify frame validation (length, type, flags) vs C for edge cases (e.g., oversized settings, padding lengths).
- `h2_connection.jl`, `h2_stream.jl`, `h2_stream_manager.jl`:
  - Connection and stream state machines track C’s design, but rely on Julia task scheduling for timing and callbacks.
  - Flow-control windows are represented in `UInt32/UInt64`; check overflow behavior vs C’s `aws_add_size_checked` usage.

### HPACK (`hpack.jl`, `hpack_huffman.jl`)
- Dynamic table stores `(String, String)` entries, so header values are always valid UTF‑8.
  - C allows raw bytes; this is a behavioral difference if peers send non‑UTF8 header values.
- Huffman tables and integer coding appear faithful to RFC 7541, but outputs are materialized into `String` not byte buffers.
- Dynamic table resizing and eviction logic is correct structurally but uses a `Vector` ring buffer without explicit allocator control.

### Connection Manager & Monitoring
- `connection_manager.jl`:
  - Uses `Vector` for idle/pending queues; C uses intrusive lists and atomics.
  - Thread-safety depends on caller discipline; verify race windows vs C’s internal locks.
- `connection_monitor.jl`:
  - Monitoring timers depend on Julia `time_ns` and task scheduling; throughput enforcement timing may deviate under load.

### Proxy & WebSocket
- `proxy.jl` and `websocket.jl`:
  - WebSocket upgrade logic is present; verify header normalization and close frame semantics vs C.
  - Proxy CONNECT, auth strategies are partially implemented; confirm NTLM strategy parity if expected.

## Notable Parity Risks
- **Non‑UTF8 header names/values**: C treats them as opaque bytes; Julia uses `String` and may throw or normalize.
- **Zero‑copy behavior**: Most parsing/encoding uses fresh allocations rather than cursor slices into shared buffers.
- **Timing behavior**: Connection manager timeouts and stream scheduling depend on Julia task scheduling, which may differ from C’s event loop.

## Suggested Validation
- Fuzz tests for H1/H2 parsers with malformed/edge-case bytes.
- HPACK encode/decode round‑trip tests with non‑UTF8 byte sequences (should either match C or explicitly reject).
- Concurrency stress tests for connection manager acquisition/release with high churn and timeouts.

