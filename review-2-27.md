# AwsHTTP Review 2026-02-27 Action List

## Rules (from request)
For each item, always do all steps in order:
1. Fix implementation.
2. Add specific tests for the item.
3. Run full test suite (`julia --project=. test/runtests.jl`) and ensure pass.
4. Commit code + tests.
5. Mark the item completed in this file.
6. Move to the next item.

Status legend: `[ ]` pending, `[x]` completed.

## P0 (Critical)
- [x] `A01` Fix H2 GOAWAY `last_stream_id` tracking (`latest_peer_stream_id` not updated). Refs: `src/h2_connection.jl:64,425,428,854`.
- [x] `A02` Enforce incoming H2 stream ID/state legality (odd/even, monotonicity, GOAWAY/closed-stream rules). Refs: `src/h2_connection.jl:856,878`; C parity: `source/h2_connection.c:1257,1726`.
- [x] `A03` Fix H2 flow-control accounting to include DATA padding bytes. Refs: `src/h2_connection.jl:893`, `src/h2_stream.jl:1025`, `src/h2_frames.jl:915`.
- [x] `A04` Stop reflecting inbound PRIORITY back outbound. Refs: `src/h2_connection.jl:919`, `src/h2_stream.jl:640`.
- [x] `A05` Fix H2 frame encoding bugs: base64url transform, 24-bit payload-length guard, stream-id high-bit validation. Refs: `src/h2_frames.jl:158,169,281,487,666`.
- [x] `A06` Reject incomplete HPACK block at END_HEADERS (`ONGOING` must error). Refs: `src/h2_frames.jl:1059,1065`.
- [x] `A07` Enforce `max_header_list_size` / header-block size limits during H2 decode. Refs: `src/h2_frames.jl:767,1000,1048`.
- [x] `A08` Preserve H1 server response ordering invariants across queued streams. Refs: `src/h1_connection.jl:1010`.
- [x] `A09` Handle pipelined H1 requests arriving in one read buffer without parse failure. Refs: `src/h1_connection.jl:395,600,1049`; `src/h1_decoder.jl:547`.
- [x] `A10` Treat unexpected client inbound bytes (no `incoming_stream`) as protocol error path equivalent to C. Refs: `src/h1_connection.jl:1050`.
- [x] `A11` Fix H1 `Connection` token handling (`keep-alive, close`) and close-delimited response finalization behavior. Refs: `src/h1_connection.jl:446`, `src/h1_decoder.jl:403,448,613`.
- [x] `A12` Fix connection-manager shutdown so leased/open connections are not orphaned. Refs: `src/connection_manager.jl:166,179,327,337`.
- [x] `A13` Do not reuse connections that are open but disallow new requests. Refs: `src/connection_manager.jl:264,332`.
- [x] `A14` Wire proxy options into client connect path (no more always-direct connect). Refs: `src/connection.jl:47`, `src/client_bootstrap.jl:99,204`.
- [x] `A15` Implement CONNECT tunneling handshake/bootstrap path parity for proxy mode. Refs: `src/proxy.jl`, `src/client_bootstrap.jl`; C parity: `source/proxy_connection.c`.
- [x] `A16` Tighten WebSocket TEXT/CLOSE validation (UTF-8, close code/reason, payload len 1 invalid). Refs: `src/websocket.jl:233,411,553`.
- [x] `A17` Harden WebSocket length handling (`UInt64 -> Int` overflow crash). Refs: `src/websocket.jl:311,337,352`.
- [ ] `A18` Enforce WebSocket max payload pre-buffering to avoid allocation DoS. Refs: `src/websocket.jl:336,587,603`.
- [ ] `A19` Stop processing additional frames after CLOSE is received in same buffer. Refs: `src/websocket.jl:593,655`.
- [ ] `A20` Fix HPACK incremental Huffman decode state across fragmented input. Refs: `src/hpack.jl:488,495,506,830,846`.
- [ ] `A21` Replace HPACK exception-prone integer conversions with checked protocol errors. Refs: `src/hpack.jl:476,486,786,811,870`.
- [ ] `A22` Clear HPACK dynamic-table ring slots on eviction/cleanup to avoid stale retention. Refs: `src/hpack.jl:132,135,190`.

## P1 (High)
- [ ] `A23` Apply complete H2 SETTINGS ACK semantics and bounds/error handling parity. Refs: `src/h2_connection.jl:328,397`.
- [ ] `A24` Resolve/fail pending H2 ping/settings futures on mismatch/shutdown paths. Refs: `src/h2_connection.jl:385,544,547,1115`.
- [ ] `A25` Enforce H2 max-concurrent-streams on incoming and outgoing activation paths. Refs: `src/h2_connection.jl:865`; `src/h2_stream.jl:499`.
- [ ] `A26` Align H2 stream-manager acquire/activation semantics (stream-vs-connection contract) and option wiring. Refs: `src/h2_stream_manager.jl:275,295,53,377`.
- [ ] `A27` Tighten H2 stream header validation (pseudo-header ordering/requirements, duplicate content-length). Refs: `src/h2_stream.jl:936,973`.
- [ ] `A28` Tighten H2 priority/dependency validation and tree updates parity. Refs: `src/h2_stream.jl:185,511,635`.
- [ ] `A29` Fix H2 trailing-header encode-failure semantics (do not silently clear queued trailers). Refs: `src/h2_stream.jl:886,894,900`.
- [ ] `A30` Fix H2 CONNECT/HEAD/304 handling edge cases parity. Refs: `src/h2_stream.jl:149,658,1036`.
- [ ] `A31` Make H1 stream cancel lifecycle safe (prevent canceled stream reuse/selection). Refs: `src/h1_stream.jl:327,403`; `src/h1_connection.jl:1011`.
- [ ] `A32` Fix H1 flow-control/manual-window semantics to avoid effectively unbounded behavior. Refs: `src/h1_stream.jl:260,295,342`; `src/h1_connection.jl:1124`.
- [ ] `A33` Guard H1 stream-id exhaustion/wraparound. Refs: `src/h1_connection.jl:772`.
- [ ] `A34` Make `h1_stream_activate!` idempotent / prevent double activation. Refs: `src/h1_connection.jl:822`.
- [ ] `A35` Enforce H1 chunk/trailer state invariants and completion semantics. Refs: `src/h1_stream.jl:377,391`.
- [ ] `A36` Handle `on_request_done` callback failures in H1/H2 paths consistently. Refs: `src/h1_connection.jl:635`; `src/h2_stream.jl:1092`.
- [ ] `A37` Wire `proxy_request_transform` hook into actual request path. Refs: `src/h1_connection.jl:63`; `src/client_bootstrap.jl:153`.
- [ ] `A38` Improve proxy auth fallback + sequence strategy retry/callback semantics parity. Refs: `src/proxy.jl:84,118,187,265,280`.
- [ ] `A39` Implement richer `no_proxy` semantics (CIDR, IPv6, normalization, port behavior) or document intentional divergence. Refs: `src/proxy.jl:304`.
- [ ] `A40` Wire `http2_options` and `monitoring_options` through client bootstrap/handlers. Refs: `src/connection.jl:44,48`; `src/client_bootstrap.jl:17,53,204`.
- [ ] `A41` Fix server channel-map synchronization race (mixed locked/unlocked access). Refs: `src/server.jl:84,92,132`.
- [ ] `A42` Propagate server startup/listener setup failures and clean up owned ELG on constructor failure. Refs: `src/server.jl:241,268,279`.
- [ ] `A43` Improve H2 admission behavior after stop-new-requests/GOAWAY (reject new incoming streams). Refs: `src/h2_connection.jl:446,856,878,1010`.

## P2 (Medium)
- [ ] `A44` Tighten `strutil` validator parity for field-value/header-name/method/request-target semantics. Refs: `src/strutil.jl:39,56,99,115`.
- [ ] `A45` Align/clarify RandomAccessSet behavior parity and idempotency semantics; add tests. Refs: `src/strutil.jl:133,152`.
- [ ] `A46` Tighten WebSocket handshake token parsing and subprotocol selection semantics (`Connection` token parse, case/order behavior). Refs: `src/websocket.jl:771,799`.
- [ ] `A47` Decide/implement `ws_decoder_new(on_payload=...)` behavior (currently inert) and test/document accordingly. Refs: `src/websocket.jl:199,365`.
- [ ] `A48` Address WebSocket API-surface parity gaps (connect/upgrade/channel lifecycle) or explicitly re-scope parity target in docs/roadmap.
- [ ] `A49` Address manager/stream-manager and push-promise public option-surface parity gaps or explicitly re-scope parity target in docs/roadmap.

## P3 (Coverage + hardening)
- [ ] `A50` Add missing regression/integration coverage identified in audit: H2 fragmentation/PUSH_PROMISE matrix, h2c e2e/failure cleanup, manager lifecycle/culling edge cases, websocket bootstrap async matrix, TLS/stress parity cases.
