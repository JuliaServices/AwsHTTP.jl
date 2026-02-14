# AwsIO + AwsHTTP Port Review

Review date: 2026-01-31

## Scope & references

- **Julia ports:** `AwsIO/` and `AwsHTTP/`
- **C references:**
  - `~/aws-c-io` (aws-c-io)
  - `~/aws-c-common` (aws-c-common dependency used by aws-c-io)
  - `~/aws-c-http` (Jacob's fork with HTTP/2 server/spec extensions)
- **Known gap source:** `AwsIO/aws-c-io-parity-roadmap.md`

## Executive summary (highest‑impact findings)

1) **AwsHTTP library init/cleanup is missing core C behavior**: no `aws_io_library_init()`, no compression init, no error/log subject registration, no HPACK static table init, no managed thread joins on cleanup.
2) **AwsHTTP server is effectively a stub**: `server.jl` does not bind/listen/accept or integrate with `AwsIO` channel bootstrap. Server‑side parity is not present.
3) **AwsHTTP connection manager + HTTP/2 stream manager are simplified and ignore multiple C behaviors**: no acquisition timeouts, no ping/throughput timers, no event‑loop integration, no thread‑safety, and several options are unused.
4) **Proxy support is incomplete**: NTLM/Kerberos strategies and env‑var discovery are missing; only Basic/identity behaviors are implemented.
5) **AwsIO uses finalizers and un‑errormonitored `Threads.@spawn`** (contrary to repo rules and `PORTING_PATTERNS.md`), creating nondeterministic cleanup and hidden task failures.

## Known, explicit gaps (from AwsIO parity roadmap — acknowledged)

- **Out of scope by design:** `file_utils.h` and `uri.h` shims in aws‑c‑io.
- **Windows‑specific gaps:** IOCP event loop, Winsock sockets, IOCP pipes, Schannel TLS, Windows host resolver.
- **iOS/SecItem gaps:** SecItem backend parity for Apple Network Framework TLS.

## Cross‑cutting findings (applies across files)

- **Finalizers present in AwsIO I/O layer** (`io/stream.jl`, `io/crypto_primitives.jl`, `io/pki_utils.jl`, `io/tls_channel_handler.jl`), despite the project’s “no finalizers” pattern. This is a divergence from C’s explicit ownership/release semantics and may cause nondeterministic cleanup.
- **`Threads.@spawn` without `errormonitor`** in `common/thread.jl`, `common/thread_scheduler.jl`, and `io/event_loop.jl`. This violates repository guidance and risks silent task failures.
- **Non‑concrete fields**: `structs-to-fix.md` enumerates multiple `Any`/`Function` fields in both AwsIO and AwsHTTP. These violate `PORTING_PATTERNS.md` (no abstract fields) and will cause dynamic dispatch in hot paths.

---

# AwsIO review (Julia vs aws‑c‑common + aws‑c‑io)

## Mapping note
`AwsIO/src/common/*` corresponds primarily to **aws‑c‑common** (`~/aws-c-common/source` + `~/aws-c-common/include`).
`AwsIO/src/io/*` corresponds to **aws‑c‑io** (`~/aws-c-io/source` + `~/aws-c-io/include`).

## AwsIO/src/common (aws‑c‑common parity)

- `AwsIO/src/common/platform.jl` → `aws-c-common/include/aws/common/platform.h`: **OK** (platform flags + constants).
- `AwsIO/src/common/macros.jl` → `aws-c-common/include/aws/common/macros.h`: **OK**.
- `AwsIO/src/common/registry.jl` → internal registry helpers (no direct C analog): **OK**, but relies on `Dict`‑like behavior.
- `AwsIO/src/common/assert.jl` → `source/assert.c`, `include/aws/common/assert.h`: **OK**.
- `AwsIO/src/common/error.jl` → `source/error.c`, `include/aws/common/error.h`: **OK**.
- `AwsIO/src/common/shutdown_types.jl` → `include/aws/common/shutdown_types.h`: **OK**.
- `AwsIO/src/common/logging_types.jl` → `include/aws/common/logging.h`: **OK**.
- `AwsIO/src/common/log_writer.jl` → `source/log_writer.c`, `include/aws/common/log_writer.h`: **OK**.
- `AwsIO/src/common/log_channel.jl` → `source/log_channel.c`, `include/aws/common/log_channel.h`: **OK**.
- `AwsIO/src/common/math.jl` → `source/math.c`, `include/aws/common/math.h`: **OK**.
- `AwsIO/src/common/byte_order.jl` → `include/aws/common/byte_order.h`: **OK**.
- `AwsIO/src/common/zero.jl` → `include/aws/common/zero.h`: **OK**.
- `AwsIO/src/common/array_list.jl` → `source/array_list.c`, `include/aws/common/array_list.h`: **OK**.
- `AwsIO/src/common/linked_list.jl` → `include/aws/common/linked_list.h`: **OK**.
- `AwsIO/src/common/priority_queue.jl` → `source/priority_queue.c`, `include/aws/common/priority_queue.h`: **OK**.
- `AwsIO/src/common/byte_buf.jl` → `source/byte_buf.c`, `include/aws/common/byte_buf.h`: **OK**. (Uses `Memory` + `WeakKeyDict` to preserve owners; parity OK.)
- `AwsIO/src/common/file.jl` → `source/file.c`, `include/aws/common/file.h`: **OK**.
- `AwsIO/src/common/string.jl` → `source/string.c`, `include/aws/common/string.h`: **OK**.
- `AwsIO/src/common/hash_table.jl` → `source/hash_table.c`, `include/aws/common/hash_table.h`: **OK**.
- `AwsIO/src/common/cache.jl` → `source/cache.c`, `include/aws/common/cache.h`: **OK**.
- `AwsIO/src/common/lru_cache.jl` → `source/lru_cache.c`, `include/aws/common/lru_cache.h`: **OK**.
- `AwsIO/src/common/clock.jl` → `source/clock.c`, `include/aws/common/clock.h`: **OK**.
- `AwsIO/src/common/time.jl` → `source/time.c`, `include/aws/common/time.h`: **OK**.
- `AwsIO/src/common/date_time.jl` → `source/date_time.c`, `include/aws/common/date_time.h`: **OK**.
- `AwsIO/src/common/log_formatter.jl` → `source/log_formatter.c`, `include/aws/common/log_formatter.h`: **OK**.
- `AwsIO/src/common/logging.jl` → `source/logging.c`, `include/aws/common/logging.h`: **OK**.
- `AwsIO/src/common/statistics.jl` → `source/statistics.c`, `include/aws/common/statistics.h`: **OK**.
- `AwsIO/src/common/device_random.jl` → `source/device_random.c`, `include/aws/common/device_random.h`: **OK**.
- `AwsIO/src/common/encoding.jl` → `source/encoding.c`, `include/aws/common/encoding.h`: **OK**.
- `AwsIO/src/common/system_info.jl` → `source/system_info.c`, `include/aws/common/system_info.h`: **OK**.
- `AwsIO/src/common/uuid.jl` → `source/uuid.c`, `include/aws/common/uuid.h`: **OK**.
- `AwsIO/src/common/mutex.jl` → `source/mutex.c`, `include/aws/common/mutex.h`: **OK**.
- `AwsIO/src/common/condition_variable.jl` → `source/condition_variable.c`, `include/aws/common/condition_variable.h`: **OK**.
- `AwsIO/src/common/thread.jl` → `source/thread.c`, `include/aws/common/thread.h`: **Issue**: `Threads.@spawn` not wrapped with `errormonitor`.
- `AwsIO/src/common/thread_shared.jl` → `source/thread_shared.c`, `include/aws/common/private/thread_shared.h`: **OK**.
- `AwsIO/src/common/task_scheduler.jl` → `source/task_scheduler.c`, `include/aws/common/task_scheduler.h`: **OK**.
- `AwsIO/src/common/common.jl` → `source/common.c`, `include/aws/common/common.h`: **OK**.
- `AwsIO/src/common/lifo_cache.jl` → `source/lifo_cache.c`, `include/aws/common/lifo_cache.h`: **OK**.
- `AwsIO/src/common/fifo_cache.jl` → `source/fifo_cache.c`, `include/aws/common/fifo_cache.h`: **OK**.
- `AwsIO/src/common/xml_parser.jl` → `source/xml_parser.c`, `include/aws/common/xml_parser.h`: **OK**.
- `AwsIO/src/common/command_line_parser.jl` → `source/command_line_parser.c`, `include/aws/common/command_line_parser.h`: **Mismatch** — API shape differs (state object + `CliStep` vs global `optind/optarg` and `optstring` parsing). Not parity‑equivalent.
- `AwsIO/src/common/uri.jl` → `source/uri.c`, `include/aws/common/uri.h`: **OK**.
- `AwsIO/src/common/environment.jl` → `source/environment.c`, `include/aws/common/environment.h`: **OK**.
- `AwsIO/src/common/process.jl` → `source/process_common.c`, `include/aws/common/process.h`: **OK**.
- `AwsIO/src/common/array_list.jl` → `source/array_list.c`, `include/aws/common/array_list.h`: **OK**.
- `AwsIO/src/common/posix_common.jl` → `include/aws/common/posix/common.inl`: **OK**.
- `AwsIO/src/common/ring_buffer.jl` → `source/ring_buffer.c`, `include/aws/common/ring_buffer.h`: **OK**.
- `AwsIO/src/common/cbor.jl` → `source/cbor.c`, `include/aws/common/cbor.h`: **Review note** — hand‑rolled CBOR implementation vs libcbor; tests exist but parity risk for edge‑cases.
- `AwsIO/src/common/json.jl` → `source/json.c`, `include/aws/common/json.h`: **Review note** — JSON.jl yields Int/Float variations vs cJSON double; verify numeric fidelity in edge cases.
- `AwsIO/src/common/system_resource_util.jl` → `source/system_resource_utils.c`, `include/aws/common/system_resource_util.h`: **OK**.
- `AwsIO/src/common/cpuid.jl` → `source/arch/*/cpuid.c`, `include/aws/common/cpuid.h`: **OK** (generic CPU feature detection).
- `AwsIO/src/common/linked_hash_table.jl` → `source/linked_hash_table.c`, `include/aws/common/linked_hash_table.h`: **OK**.
- `AwsIO/src/common/host_utils.jl` → `source/host_utils.c`, `include/aws/common/host_utils.h`: **OK**.
- `AwsIO/src/common/thread_scheduler.jl` → `source/thread_scheduler.c`, `include/aws/common/thread_scheduler.h`: **Issue** — `Threads.@spawn` missing `errormonitor`.

## AwsIO/src/io (aws‑c‑io parity)

- `AwsIO/src/io/io.jl` → `source/io.c`, `include/aws/io/io.h`: **OK** for constants; **note** uses `LibAwsCommon/LibAwsCal` init for crypto.
- `AwsIO/src/io/event_loop.jl` → `source/event_loop.c`, `include/aws/io/event_loop.h`: **OK**; **issue**: `Threads.@spawn` without `errormonitor` in `event_loop_group_release!`.
- `AwsIO/src/io/epoll_event_loop.jl` → `source/linux/epoll_event_loop.c`: **OK** (eventfd + pipe fallback, edge‑triggered behavior).
- `AwsIO/src/io/kqueue_event_loop.jl` → `source/bsd/kqueue_event_loop.c`: **OK**.
- `AwsIO/src/io/dispatch_queue_event_loop.jl` → `source/darwin/dispatch_queue_event_loop.c`: **OK** (Apple only).
- `AwsIO/src/io/iocp_event_loop.jl` → `source/windows/iocp/iocp_event_loop.c`: **Stub** (known gap).
- `AwsIO/src/io/socket.jl` → `source/socket.c`, `include/aws/io/socket.h`: **OK** (core types). Non‑concrete callback fields remain (see `structs-to-fix.md`).
- `AwsIO/src/io/posix_socket.jl` → `source/posix/socket.c`, `source/socket_shared.c`: **OK** (POSIX backend).
- `AwsIO/src/io/apple_nw_socket.jl` → `source/darwin/nw_socket.c`: **OK** (Apple Network Framework).
- `AwsIO/src/io/winsock_socket.jl` → `source/windows/iocp/socket.c`: **Stub** (known gap).
- `AwsIO/src/io/pipe.jl` → `source/posix/pipe.c`, `include/aws/io/pipe.h`: **OK**.
- `AwsIO/src/io/iocp_pipe.jl` → `source/windows/iocp/pipe.c`: **Stub** (known gap).
- `AwsIO/src/io/channel.jl` → `source/channel.c`, `include/aws/io/channel.h`: **OK**; **note** many `Any`/`Function` fields (see `structs-to-fix.md`).
- `AwsIO/src/io/socket_channel_handler.jl` → `source/socket_channel_handler.c`, `include/aws/io/socket_channel_handler.h`: **OK**.
- `AwsIO/src/io/channel_bootstrap.jl` → `source/channel_bootstrap.c`, `include/aws/io/channel_bootstrap.h`: **OK**.
- `AwsIO/src/io/host_resolver.jl` → `source/host_resolver.c` + platform resolvers: **OK** (world‑age safe callbacks).
- `AwsIO/src/io/retry_strategy.jl` → `source/retry_strategy.c`, `source/exponential_backoff_retry_strategy.c`, `source/standard_retry_strategy.c`, `source/no_retry_strategy.c`: **OK**.
- `AwsIO/src/io/async_stream.jl` → `source/async_stream.c`, `include/aws/io/async_stream.h`: **OK**.
- `AwsIO/src/io/stream.jl` → `source/stream.c`, `include/aws/io/stream.h`: **Issue** — uses finalizers for cleanup (non‑deterministic vs C refcount).
- `AwsIO/src/io/future.jl` → `source/future.c`, `include/aws/io/future.h`: **OK**.
- `AwsIO/src/io/message_pool.jl` → `source/message_pool.c`, `include/aws/io/message_pool.h`: **OK**.
- `AwsIO/src/io/shared_library.jl` → `source/posix/shared_library.c`, `source/windows/shared_library.c`: **OK**.
- `AwsIO/src/io/pem.jl` → `source/pem.c`, `include/aws/io/pem.h`: **OK**.
- `AwsIO/src/io/pki_utils.jl` → `source/posix/*_pki_utils.c`, `source/darwin/*_pki_utils.c`, `source/windows/windows_pki_utils.c`: **Issue** — multiple `ERROR_PLATFORM_NOT_SUPPORTED` branches, plus finalizers; Windows + SecItem parts are incomplete.
- `AwsIO/src/io/tls_channel_handler.jl` → `source/tls_channel_handler.c`, `source/tls_channel_handler_shared.c`, `source/s2n/*`, `source/darwin/secure_transport_tls_channel_handler.c`, `source/windows/secure_channel_tls_handler.c`: **Issue** — multiple unimplemented branches (Windows/SecItem), and finalizers present.
- `AwsIO/src/io/alpn_handler.jl` → `source/alpn_handler.c`: **OK**.
- `AwsIO/src/io/tracing.jl` → `source/tracing.c`: **OK** (no‑op hooks).
- `AwsIO/src/io/pkcs11.jl` → `source/pkcs11_lib.c`, `source/pkcs11_tls_op_handler.c`, `include/aws/io/pkcs11.h`: **OK** for PKCS#11 core.
- `AwsIO/src/io/winsock_init.jl` → `source/windows/winsock_init.c`: **Stub** (known gap).
- `AwsIO/src/io/crypto_primitives.jl` → uses `LibAwsCal` equivalents: **Issue** — finalizers used for keypair release.
- `AwsIO/src/io/statistics.jl` → `source/statistics.c`, `include/aws/io/statistics.h`: **OK**.
- `AwsIO/src/io/aws_byte_helpers.jl` → helper glue (no direct C file): **OK**.

## AwsIO/tests (coverage vs aws‑c‑common + aws‑c‑io tests)

- **Ported/covered:** PEM, TLS, tracing, PKI utils, io_testing_channel, shared_library, vsock, statistics, host_resolver, channel_bootstrap, async_stream, pipe, retry_strategy, ALPN, socket handler, PKCS11, channel, future, event_loop, stream, socket.
- **Not fully matched:** aws‑c‑io `tests/vcc/*` (stress and concurrency) are not obviously mirrored as separate suites. Windows IOCP tests are absent (expected due to gap). aws‑c‑common’s extensive logging tests are only partially exercised.

---

# AwsHTTP review (Julia vs aws‑c‑http)

## AwsHTTP/src (aws‑c‑http parity)

- `AwsHTTP/src/AwsHTTP.jl` → library module glue: **OK**.
- `AwsHTTP/src/http.jl` → `source/http.c`, `include/aws/http/http.h`, `status_code.h`, `http_impl.h`: **Major gap** — `http_library_init/clean_up` omits error/log registration, compression init, HPACK static table init, and `aws_io_library_init`. Fatal‑assert helper is missing.
- `AwsHTTP/src/request_response.jl` → `source/request_response.c`, `include/aws/http/request_response.h`: **Partial** — core headers/messages are present, but body stream handling lacks acquire/release semantics (and InputStream not ported).
- `AwsHTTP/src/h1_encoder.jl` → `source/h1_encoder.c`, `include/aws/http/private/h1_encoder.h`: **OK** (encoding logic present). Verify against C tests; no parity regressions observed in code skim.
- `AwsHTTP/src/h1_decoder.jl` → `source/h1_decoder.c`, `include/aws/http/private/h1_decoder.h`: **OK** (state machine present). Note: uses `String` parsing (allocations) vs cursor parsing in C.
- `AwsHTTP/src/h1_stream.jl` → `source/h1_stream.c`, `include/aws/http/private/h1_stream.h`: **Partial** — h2c upgrade options are defined but no upgrade path exists in code.
- `AwsHTTP/src/h1_connection.jl` → `source/h1_connection.c`, `include/aws/http/private/h1_connection.h`: **Partial** — `response_first_byte_timeout_ms` stored but never enforced; non‑concrete fields remain.
- `AwsHTTP/src/hpack_huffman.jl` → `source/hpack_huffman_static.c`, `include/aws/http/private/hpack_huffman_static_table.def`: **OK**.
- `AwsHTTP/src/hpack.jl` → `source/hpack.c`, `hpack_encoder.c`, `hpack_decoder.c`, `include/aws/http/private/hpack.h`: **OK**.
- `AwsHTTP/src/h2_frames.jl` → `source/h2_frames.c`, `h2_decoder.c`, `include/aws/http/private/h2_frames.h`, `h2_decoder.h`: **OK** (frame encode/decode present).
- `AwsHTTP/src/h2_connection.jl` → `source/h2_connection.c`, `include/aws/http/private/h2_connection.h`: **OK** core logic, but uses `Dict/Vector` + `Any` (pattern deviation).
- `AwsHTTP/src/h2_stream.jl` → `source/h2_stream.c`, `include/aws/http/private/h2_stream.h`: **OK**.
- `AwsHTTP/src/connection.jl` → `source/connection.c`, `include/aws/http/connection.h`: **Partial** — `proxy_options` and `monitoring_options` are defined but unused; `h2c_upgrade` option unused.
- `AwsHTTP/src/client_bootstrap.jl` → `source/connection.c` (client flow): **Partial** — ignores `proxy_options`, `monitoring_options`, and `h2c_upgrade` behavior; passes through but doesn’t enforce `response_first_byte_timeout_ms`.
- `AwsHTTP/src/server.jl` → `include/aws/http/server.h` + server parts of `source/connection.c`: **Major gap** — no listener setup or accept flow; server is a container only.
- `AwsHTTP/src/connection_manager.jl` → `source/connection_manager.c`, `include/aws/http/connection_manager.h`: **Major gap** — synchronous creation, no timeouts, no event‑loop integration, no thread‑safety, and ignores several options.
- `AwsHTTP/src/h2_stream_manager.jl` → `source/http2_stream_manager.c`, `include/aws/http/http2_stream_manager.h`: **Major gap** — no ping/timeout handling, no async connection acquisition, no event‑loop integration.
- `AwsHTTP/src/strutil.jl` → `source/strutil.c`, `random_access_set.c`: **Partial** — RandomAccessSet uses `Vector`+`Dict` (pattern deviation) and lacks explicit allocator semantics.
- `AwsHTTP/src/connection_monitor.jl` → `source/connection_monitor.c`, `statistics.c`, `include/aws/http/private/connection_monitor.h`, `include/aws/http/statistics.h`: **OK** core monitoring logic present, but not wired into connections.
- `AwsHTTP/src/proxy.jl` → `proxy_strategy.c`, `proxy_connection.c`, `no_proxy.c`, `include/aws/http/proxy.h`: **Major gap** — only Basic auth + identity strategies. NTLM/Kerberos and env‑var parsing are missing.
- `AwsHTTP/src/websocket.jl` → `source/websocket.c`, `websocket_encoder.c`, `websocket_decoder.c`, `websocket_bootstrap.c`: **OK** encoder/decoder + handler, but verify handshake + upgrade vs C tests.

## AwsHTTP/tests (coverage vs aws‑c‑http tests)

- `AwsHTTP/test/http_tests.jl` covers **Phase 0 constants only** (errors, status codes, headers, enums).
- **Missing parity with C tests:** no ported tests for H1/H2 decoders/encoders, connection manager, stream manager, websocket, proxy, or integration tests.

---

# Action items (prioritized)

1) **Implement full `http_library_init/clean_up` parity** (error/log registration, HPACK static tables, compression init, AwsIO init, managed thread join on cleanup).
2) **Implement real HTTP server** (listener + accept, channel bootstrap integration, H1/H2 dispatch).
3) **Bring connection manager and H2 stream manager to parity** (timeouts, async connection acquisition, event‑loop tasking, thread‑safety, respect all options).
4) **Proxy parity** (NTLM/Kerberos strategies, env‑var parsing, tunneling/forwarding negotiation flow, proxy connection integration).
5) **Wire monitoring + timeouts** (response first‑byte timeout, throughput monitor integration).
6) **Remove/replace finalizers in AwsIO I/O layer** and adopt explicit lifetime control.
7) **Wrap all `Threads.@spawn` with `errormonitor`.**
8) **Port C test suite coverage** for AwsHTTP (h1/h2/websocket/manager/proxy) and vcc stress tests for AwsIO.

