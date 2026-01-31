using Test
using AwsHTTP
using AwsIO

# ─── Phase 0: Core library, errors, logging, status codes ───

@testset "HTTP library init/cleanup" begin
    # Init is idempotent
    AwsHTTP.http_library_init()
    @test AwsHTTP.http_library_initialized() == true
    AwsHTTP.http_library_init()  # second call is no-op
    @test AwsHTTP.http_library_initialized() == true

    # Cleanup is idempotent
    AwsHTTP.http_library_clean_up()
    @test AwsHTTP.http_library_initialized() == false
    AwsHTTP.http_library_clean_up()  # second call is no-op
    @test AwsHTTP.http_library_initialized() == false

    # Re-init works after cleanup
    AwsHTTP.http_library_init()
    @test AwsHTTP.http_library_initialized() == true
    AwsHTTP.http_library_clean_up()
end

@testset "HTTP error codes" begin
    # Verify error codes are in the correct range
    begin_range = AwsIO.ERROR_ENUM_BEGIN_RANGE(AwsHTTP.HTTP_PACKAGE_ID)
    end_range = AwsIO.ERROR_ENUM_END_RANGE(AwsHTTP.HTTP_PACKAGE_ID)

    @test AwsHTTP.ERROR_HTTP_UNKNOWN == begin_range
    @test AwsHTTP.ERROR_HTTP_END_RANGE == end_range

    # Verify sequential ordering (no gaps)
    @test AwsHTTP.ERROR_HTTP_HEADER_NOT_FOUND == AwsHTTP.ERROR_HTTP_UNKNOWN + 1
    @test AwsHTTP.ERROR_HTTP_INVALID_HEADER_FIELD == AwsHTTP.ERROR_HTTP_UNKNOWN + 2
    @test AwsHTTP.ERROR_HTTP_INVALID_HEADER_NAME == AwsHTTP.ERROR_HTTP_UNKNOWN + 3
    @test AwsHTTP.ERROR_HTTP_INVALID_HEADER_VALUE == AwsHTTP.ERROR_HTTP_UNKNOWN + 4
    @test AwsHTTP.ERROR_HTTP_INVALID_METHOD == AwsHTTP.ERROR_HTTP_UNKNOWN + 5
    @test AwsHTTP.ERROR_HTTP_INVALID_PATH == AwsHTTP.ERROR_HTTP_UNKNOWN + 6
    @test AwsHTTP.ERROR_HTTP_INVALID_STATUS_CODE == AwsHTTP.ERROR_HTTP_UNKNOWN + 7
    @test AwsHTTP.ERROR_HTTP_MISSING_BODY_STREAM == AwsHTTP.ERROR_HTTP_UNKNOWN + 8
    @test AwsHTTP.ERROR_HTTP_INVALID_BODY_STREAM == AwsHTTP.ERROR_HTTP_UNKNOWN + 9
    @test AwsHTTP.ERROR_HTTP_CONNECTION_CLOSED == AwsHTTP.ERROR_HTTP_UNKNOWN + 10

    # Verify all 47 error codes have descriptions
    for code in AwsHTTP.ERROR_HTTP_UNKNOWN:AwsHTTP.ERROR_HTTP_CONNECTION_MANAGER_MAX_PENDING_ACQUISITIONS_EXCEEDED
        @test AwsHTTP.http_error_str(code) != "Unknown HTTP error"
        @test AwsHTTP.http_error_name(code) != "UNKNOWN"
    end

    # Verify total count of error codes matches C (47 named errors)
    count = AwsHTTP.ERROR_HTTP_CONNECTION_MANAGER_MAX_PENDING_ACQUISITIONS_EXCEEDED - AwsHTTP.ERROR_HTTP_UNKNOWN + 1
    @test count == 47

    # Verify all error codes fit within range
    @test AwsHTTP.ERROR_HTTP_CONNECTION_MANAGER_MAX_PENDING_ACQUISITIONS_EXCEEDED < AwsHTTP.ERROR_HTTP_END_RANGE
end

@testset "HTTP/2 error codes" begin
    # Verify all 14 HTTP/2 error codes
    @test UInt32(AwsHTTP.Http2ErrorCode.NO_ERROR) == 0x00
    @test UInt32(AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR) == 0x01
    @test UInt32(AwsHTTP.Http2ErrorCode.INTERNAL_ERROR) == 0x02
    @test UInt32(AwsHTTP.Http2ErrorCode.FLOW_CONTROL_ERROR) == 0x03
    @test UInt32(AwsHTTP.Http2ErrorCode.SETTINGS_TIMEOUT) == 0x04
    @test UInt32(AwsHTTP.Http2ErrorCode.STREAM_CLOSED) == 0x05
    @test UInt32(AwsHTTP.Http2ErrorCode.FRAME_SIZE_ERROR) == 0x06
    @test UInt32(AwsHTTP.Http2ErrorCode.REFUSED_STREAM) == 0x07
    @test UInt32(AwsHTTP.Http2ErrorCode.CANCEL) == 0x08
    @test UInt32(AwsHTTP.Http2ErrorCode.COMPRESSION_ERROR) == 0x09
    @test UInt32(AwsHTTP.Http2ErrorCode.CONNECT_ERROR) == 0x0A
    @test UInt32(AwsHTTP.Http2ErrorCode.ENHANCE_YOUR_CALM) == 0x0B
    @test UInt32(AwsHTTP.Http2ErrorCode.INADEQUATE_SECURITY) == 0x0C
    @test UInt32(AwsHTTP.Http2ErrorCode.HTTP_1_1_REQUIRED) == 0x0D

    # String conversion
    @test AwsHTTP.http2_error_code_to_str(AwsHTTP.Http2ErrorCode.NO_ERROR) == "NO_ERROR"
    @test AwsHTTP.http2_error_code_to_str(AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR) == "PROTOCOL_ERROR"
    @test AwsHTTP.http2_error_code_to_str(AwsHTTP.Http2ErrorCode.CANCEL) == "CANCEL"
    @test AwsHTTP.http2_error_code_to_str(AwsHTTP.Http2ErrorCode.HTTP_1_1_REQUIRED) == "HTTP_1_1_REQUIRED"
end

@testset "HTTP log subjects" begin
    begin_range = AwsIO.LOG_SUBJECT_BEGIN_RANGE(AwsHTTP.HTTP_PACKAGE_ID)
    end_range = AwsIO.LOG_SUBJECT_END_RANGE(AwsHTTP.HTTP_PACKAGE_ID)

    @test AwsHTTP.LS_HTTP_GENERAL == begin_range
    @test AwsHTTP.LS_HTTP_LAST == end_range

    # Verify sequential ordering
    @test AwsHTTP.LS_HTTP_CONNECTION == AwsHTTP.LS_HTTP_GENERAL + 1
    @test AwsHTTP.LS_HTTP_ENCODER == AwsHTTP.LS_HTTP_GENERAL + 2
    @test AwsHTTP.LS_HTTP_DECODER == AwsHTTP.LS_HTTP_GENERAL + 3
    @test AwsHTTP.LS_HTTP_SERVER == AwsHTTP.LS_HTTP_GENERAL + 4
    @test AwsHTTP.LS_HTTP_STREAM == AwsHTTP.LS_HTTP_GENERAL + 5
    @test AwsHTTP.LS_HTTP_CONNECTION_MANAGER == AwsHTTP.LS_HTTP_GENERAL + 6
    @test AwsHTTP.LS_HTTP_STREAM_MANAGER == AwsHTTP.LS_HTTP_GENERAL + 7
    @test AwsHTTP.LS_HTTP_WEBSOCKET == AwsHTTP.LS_HTTP_GENERAL + 8
    @test AwsHTTP.LS_HTTP_WEBSOCKET_SETUP == AwsHTTP.LS_HTTP_GENERAL + 9
    @test AwsHTTP.LS_HTTP_PROXY_NEGOTIATION == AwsHTTP.LS_HTTP_GENERAL + 10

    # All subjects fit within range
    @test AwsHTTP.LS_HTTP_PROXY_NEGOTIATION < AwsHTTP.LS_HTTP_LAST
end

@testset "HTTP version enum" begin
    @test UInt8(AwsHTTP.HttpVersion.UNKNOWN) == 0
    @test UInt8(AwsHTTP.HttpVersion.HTTP_1_0) == 1
    @test UInt8(AwsHTTP.HttpVersion.HTTP_1_1) == 2
    @test UInt8(AwsHTTP.HttpVersion.HTTP_2) == 3

    @test AwsHTTP.http_version_to_str(AwsHTTP.HttpVersion.UNKNOWN) == "Unknown"
    @test AwsHTTP.http_version_to_str(AwsHTTP.HttpVersion.HTTP_1_0) == "HTTP/1.0"
    @test AwsHTTP.http_version_to_str(AwsHTTP.HttpVersion.HTTP_1_1) == "HTTP/1.1"
    @test AwsHTTP.http_version_to_str(AwsHTTP.HttpVersion.HTTP_2) == "HTTP/2"
end

@testset "HTTP status codes" begin
    # Test all status code constants exist and have correct values
    @test AwsHTTP.HTTP_STATUS_CODE_UNKNOWN == -1
    @test AwsHTTP.HTTP_STATUS_CODE_200_OK == 200
    @test AwsHTTP.HTTP_STATUS_CODE_404_NOT_FOUND == 404
    @test AwsHTTP.HTTP_STATUS_CODE_500_INTERNAL_SERVER_ERROR == 500

    # Test status text for all categories
    @test AwsHTTP.http_status_text(100) == "Continue"
    @test AwsHTTP.http_status_text(101) == "Switching Protocols"
    @test AwsHTTP.http_status_text(102) == "Processing"
    @test AwsHTTP.http_status_text(103) == "Early Hints"
    @test AwsHTTP.http_status_text(200) == "OK"
    @test AwsHTTP.http_status_text(201) == "Created"
    @test AwsHTTP.http_status_text(202) == "Accepted"
    @test AwsHTTP.http_status_text(204) == "No Content"
    @test AwsHTTP.http_status_text(301) == "Moved Permanently"
    @test AwsHTTP.http_status_text(302) == "Found"
    @test AwsHTTP.http_status_text(304) == "Not Modified"
    @test AwsHTTP.http_status_text(307) == "Temporary Redirect"
    @test AwsHTTP.http_status_text(308) == "Permanent Redirect"
    @test AwsHTTP.http_status_text(400) == "Bad Request"
    @test AwsHTTP.http_status_text(401) == "Unauthorized"
    @test AwsHTTP.http_status_text(403) == "Forbidden"
    @test AwsHTTP.http_status_text(404) == "Not Found"
    @test AwsHTTP.http_status_text(405) == "Method Not Allowed"
    @test AwsHTTP.http_status_text(408) == "Request Timeout"
    @test AwsHTTP.http_status_text(409) == "Conflict"
    @test AwsHTTP.http_status_text(413) == "Payload Too Large"
    @test AwsHTTP.http_status_text(414) == "URI Too Long"
    @test AwsHTTP.http_status_text(416) == "Range Not Satisfiable"
    @test AwsHTTP.http_status_text(429) == "Too Many Requests"
    @test AwsHTTP.http_status_text(451) == "Unavailable For Legal Reasons"
    @test AwsHTTP.http_status_text(500) == "Internal Server Error"
    @test AwsHTTP.http_status_text(501) == "Not Implemented"
    @test AwsHTTP.http_status_text(502) == "Bad Gateway"
    @test AwsHTTP.http_status_text(503) == "Service Unavailable"
    @test AwsHTTP.http_status_text(504) == "Gateway Timeout"
    @test AwsHTTP.http_status_text(511) == "Network Authentication Required"

    # Unknown status code returns empty string
    @test AwsHTTP.http_status_text(0) == ""
    @test AwsHTTP.http_status_text(999) == ""
    @test AwsHTTP.http_status_text(-1) == ""

    # Verify total count matches C (61 status codes with text)
    count = length(AwsHTTP._STATUS_TEXT)
    @test count == 61
end

@testset "HTTP method constants and lookup" begin
    # Constants
    @test AwsHTTP.HTTP_METHOD_GET == "GET"
    @test AwsHTTP.HTTP_METHOD_HEAD == "HEAD"
    @test AwsHTTP.HTTP_METHOD_POST == "POST"
    @test AwsHTTP.HTTP_METHOD_PUT == "PUT"
    @test AwsHTTP.HTTP_METHOD_DELETE == "DELETE"
    @test AwsHTTP.HTTP_METHOD_CONNECT == "CONNECT"
    @test AwsHTTP.HTTP_METHOD_OPTIONS == "OPTIONS"

    # Enum values
    @test UInt8(AwsHTTP.HttpMethod.UNKNOWN) == 0
    @test UInt8(AwsHTTP.HttpMethod.GET) == 1
    @test UInt8(AwsHTTP.HttpMethod.HEAD) == 2
    @test UInt8(AwsHTTP.HttpMethod.CONNECT) == 3

    # Case-sensitive lookup
    @test AwsHTTP.http_str_to_method("GET") == AwsHTTP.HttpMethod.GET
    @test AwsHTTP.http_str_to_method("HEAD") == AwsHTTP.HttpMethod.HEAD
    @test AwsHTTP.http_str_to_method("CONNECT") == AwsHTTP.HttpMethod.CONNECT

    # Unknown methods
    @test AwsHTTP.http_str_to_method("POST") == AwsHTTP.HttpMethod.UNKNOWN  # POST is valid but not in the "known" enum
    @test AwsHTTP.http_str_to_method("get") == AwsHTTP.HttpMethod.UNKNOWN  # case-sensitive
    @test AwsHTTP.http_str_to_method("PATCH") == AwsHTTP.HttpMethod.UNKNOWN
    @test AwsHTTP.http_str_to_method("") == AwsHTTP.HttpMethod.UNKNOWN
end

@testset "HTTP header name constants and lookup" begin
    # Pseudo-header strings
    @test AwsHTTP.HTTP_HEADER_METHOD_STR == ":method"
    @test AwsHTTP.HTTP_HEADER_SCHEME_STR == ":scheme"
    @test AwsHTTP.HTTP_HEADER_AUTHORITY_STR == ":authority"
    @test AwsHTTP.HTTP_HEADER_PATH_STR == ":path"
    @test AwsHTTP.HTTP_HEADER_STATUS_STR == ":status"

    # Scheme strings
    @test AwsHTTP.HTTP_SCHEME_HTTP == "http"
    @test AwsHTTP.HTTP_SCHEME_HTTPS == "https"

    # Case-insensitive lookup
    @test AwsHTTP.http_str_to_header_name(":method") == AwsHTTP.HttpHeaderName.METHOD
    @test AwsHTTP.http_str_to_header_name(":scheme") == AwsHTTP.HttpHeaderName.SCHEME
    @test AwsHTTP.http_str_to_header_name("content-length") == AwsHTTP.HttpHeaderName.CONTENT_LENGTH
    @test AwsHTTP.http_str_to_header_name("Content-Length") == AwsHTTP.HttpHeaderName.CONTENT_LENGTH
    @test AwsHTTP.http_str_to_header_name("CONTENT-LENGTH") == AwsHTTP.HttpHeaderName.CONTENT_LENGTH
    @test AwsHTTP.http_str_to_header_name("transfer-encoding") == AwsHTTP.HttpHeaderName.TRANSFER_ENCODING
    @test AwsHTTP.http_str_to_header_name("Transfer-Encoding") == AwsHTTP.HttpHeaderName.TRANSFER_ENCODING
    @test AwsHTTP.http_str_to_header_name("cookie") == AwsHTTP.HttpHeaderName.COOKIE
    @test AwsHTTP.http_str_to_header_name("host") == AwsHTTP.HttpHeaderName.HOST
    @test AwsHTTP.http_str_to_header_name("connection") == AwsHTTP.HttpHeaderName.CONNECTION
    @test AwsHTTP.http_str_to_header_name("upgrade") == AwsHTTP.HttpHeaderName.UPGRADE

    # Unknown headers
    @test AwsHTTP.http_str_to_header_name("x-custom-header") == AwsHTTP.HttpHeaderName.UNKNOWN
    @test AwsHTTP.http_str_to_header_name("") == AwsHTTP.HttpHeaderName.UNKNOWN

    # Case-sensitive (lowercase only) lookup
    @test AwsHTTP.http_lowercase_str_to_header_name("content-length") == AwsHTTP.HttpHeaderName.CONTENT_LENGTH
    @test AwsHTTP.http_lowercase_str_to_header_name("Content-Length") == AwsHTTP.HttpHeaderName.UNKNOWN  # not lowercase

    # All 35 known headers have string mappings
    for name_val in instances(AwsHTTP.HttpHeaderName.T)
        name_val == AwsHTTP.HttpHeaderName.UNKNOWN && continue
        str = AwsHTTP.http_header_name_to_str(name_val)
        @test !isempty(str)
        # Round-trip: str -> enum -> str
        @test AwsHTTP.http_str_to_header_name(str) == name_val
    end
end

@testset "HTTP retryable error helper" begin
    # HTTP-specific retryable errors
    @test AwsHTTP.http_error_code_is_retryable(AwsHTTP.ERROR_HTTP_CONNECTION_CLOSED) == true
    @test AwsHTTP.http_error_code_is_retryable(AwsHTTP.ERROR_HTTP_SERVER_CLOSED) == true
    @test AwsHTTP.http_error_code_is_retryable(AwsHTTP.ERROR_HTTP_PROXY_CONNECT_FAILED_RETRYABLE) == true

    # Non-retryable HTTP errors
    @test AwsHTTP.http_error_code_is_retryable(AwsHTTP.ERROR_HTTP_UNKNOWN) == false
    @test AwsHTTP.http_error_code_is_retryable(AwsHTTP.ERROR_HTTP_INVALID_METHOD) == false
    @test AwsHTTP.http_error_code_is_retryable(AwsHTTP.ERROR_HTTP_PROTOCOL_ERROR) == false

    # IO-layer retryable errors pass through
    @test AwsHTTP.http_error_code_is_retryable(AwsIO.ERROR_IO_SOCKET_CLOSED) == true
    @test AwsHTTP.http_error_code_is_retryable(AwsIO.ERROR_IO_SOCKET_CONNECTION_REFUSED) == true
end

# ─── Phase 1: HTTP headers and messages ───

@testset "HttpHeaderCompression enum" begin
    @test UInt8(AwsHTTP.HttpHeaderCompression.USE_CACHE) == 0
    @test UInt8(AwsHTTP.HttpHeaderCompression.NO_CACHE) == 1
    @test UInt8(AwsHTTP.HttpHeaderCompression.NO_FORWARD_CACHE) == 2
end

@testset "HttpHeaderBlock enum" begin
    @test UInt8(AwsHTTP.HttpHeaderBlock.MAIN) == 0
    @test UInt8(AwsHTTP.HttpHeaderBlock.INFORMATIONAL) == 1
    @test UInt8(AwsHTTP.HttpHeaderBlock.TRAILING) == 2
end

@testset "HttpHeader struct" begin
    h = AwsHTTP.HttpHeader("Content-Type", "text/html")
    @test h.name == "Content-Type"
    @test h.value == "text/html"
    @test h.compression == AwsHTTP.HttpHeaderCompression.USE_CACHE

    h2 = AwsHTTP.HttpHeader("X-Custom", "val", AwsHTTP.HttpHeaderCompression.NO_CACHE)
    @test h2.compression == AwsHTTP.HttpHeaderCompression.NO_CACHE
end

@testset "Utility functions" begin
    # Pseudo-header detection
    @test AwsHTTP.is_pseudo_header_name(":method") == true
    @test AwsHTTP.is_pseudo_header_name(":scheme") == true
    @test AwsHTTP.is_pseudo_header_name(":authority") == true
    @test AwsHTTP.is_pseudo_header_name(":path") == true
    @test AwsHTTP.is_pseudo_header_name(":status") == true
    @test AwsHTTP.is_pseudo_header_name("host") == false
    @test AwsHTTP.is_pseudo_header_name("") == false
    @test AwsHTTP.is_pseudo_header_name("content-type") == false

    # Case-insensitive name comparison
    @test AwsHTTP.http_header_name_eq("Content-Type", "content-type") == true
    @test AwsHTTP.http_header_name_eq("HOST", "host") == true
    @test AwsHTTP.http_header_name_eq("foo", "bar") == false

    # HTTP whitespace trimming
    @test AwsHTTP.trim_http_whitespace("  hello  ") == "hello"
    @test AwsHTTP.trim_http_whitespace("\thello\t") == "hello"
    @test AwsHTTP.trim_http_whitespace(" \t hello \t ") == "hello"
    @test AwsHTTP.trim_http_whitespace("hello") == "hello"
    @test AwsHTTP.trim_http_whitespace("") == ""
end

@testset "HttpHeaders creation and lifecycle" begin
    headers = AwsHTTP.http_headers_new()
    @test AwsHTTP.http_headers_count(headers) == 0

    # Acquire increments refcount
    AwsHTTP.http_headers_acquire(headers)
    # Release once (refcount 2 -> 1, should NOT clear)
    AwsHTTP.http_headers_add(headers, "foo", "bar")
    AwsHTTP.http_headers_release(headers)
    @test AwsHTTP.http_headers_count(headers) == 1

    # Release again (refcount 1 -> 0, should clear)
    AwsHTTP.http_headers_release(headers)
    @test AwsHTTP.http_headers_count(headers) == 0
end

@testset "HttpHeaders add and get" begin
    headers = AwsHTTP.http_headers_new()

    # Add headers
    @test AwsHTTP.http_headers_add(headers, "Content-Type", "text/html") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_add(headers, "Content-Length", "42") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_add(headers, "X-Custom", "value1") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 3

    # Get by name (case-insensitive)
    @test AwsHTTP.http_headers_get(headers, "content-type") == "text/html"
    @test AwsHTTP.http_headers_get(headers, "CONTENT-TYPE") == "text/html"
    @test AwsHTTP.http_headers_get(headers, "Content-Length") == "42"
    @test AwsHTTP.http_headers_get(headers, "x-custom") == "value1"

    # Get not found
    @test AwsHTTP.http_headers_get(headers, "x-missing") === nothing

    # Get by index (0-based)
    h0 = AwsHTTP.http_headers_get_index(headers, 0)
    @test h0 !== nothing
    @test h0.name == "Content-Type"
    @test h0.value == "text/html"

    h2 = AwsHTTP.http_headers_get_index(headers, 2)
    @test h2 !== nothing
    @test h2.name == "X-Custom"

    # Invalid index
    @test AwsHTTP.http_headers_get_index(headers, -1) === nothing
    @test AwsHTTP.http_headers_get_index(headers, 3) === nothing

    # Empty name is rejected
    @test AwsHTTP.http_headers_add(headers, "", "val") == AwsIO.OP_ERR
    @test AwsHTTP.http_headers_count(headers) == 3  # unchanged
end

@testset "HttpHeaders value whitespace trimming" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "X-Trimmed", "  hello world  ")
    @test AwsHTTP.http_headers_get(headers, "X-Trimmed") == "hello world"

    AwsHTTP.http_headers_add(headers, "X-Tabs", "\tvalue\t")
    @test AwsHTTP.http_headers_get(headers, "X-Tabs") == "value"
end

@testset "HttpHeaders has" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "Host", "example.com")

    @test AwsHTTP.http_headers_has(headers, "Host") == true
    @test AwsHTTP.http_headers_has(headers, "host") == true
    @test AwsHTTP.http_headers_has(headers, "HOST") == true
    @test AwsHTTP.http_headers_has(headers, "missing") == false
end

@testset "HttpHeaders get_all" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "Set-Cookie", "a=1")
    AwsHTTP.http_headers_add(headers, "Other", "middle")
    AwsHTTP.http_headers_add(headers, "Set-Cookie", "b=2")
    AwsHTTP.http_headers_add(headers, "Set-Cookie", "c=3")

    result = AwsHTTP.http_headers_get_all(headers, "Set-Cookie")
    @test result == "a=1, b=2, c=3"

    # Single value
    @test AwsHTTP.http_headers_get_all(headers, "Other") == "middle"

    # Not found
    @test AwsHTTP.http_headers_get_all(headers, "missing") === nothing
end

@testset "HttpHeaders add_array" begin
    headers = AwsHTTP.http_headers_new()
    arr = [
        AwsHTTP.HttpHeader("A", "1"),
        AwsHTTP.HttpHeader("B", "2"),
        AwsHTTP.HttpHeader("C", "3"),
    ]
    @test AwsHTTP.http_headers_add_array(headers, arr) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 3
    @test AwsHTTP.http_headers_get(headers, "A") == "1"
    @test AwsHTTP.http_headers_get(headers, "B") == "2"
    @test AwsHTTP.http_headers_get(headers, "C") == "3"

    # Array with invalid entry rolls back
    headers2 = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers2, "existing", "val")
    bad_arr = [
        AwsHTTP.HttpHeader("D", "4"),
        AwsHTTP.HttpHeader("", "invalid"),  # empty name -> error
    ]
    @test AwsHTTP.http_headers_add_array(headers2, bad_arr) == AwsIO.OP_ERR
    @test AwsHTTP.http_headers_count(headers2) == 1  # rolled back
    @test AwsHTTP.http_headers_get(headers2, "existing") == "val"
end

@testset "HttpHeaders set" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "Host", "old.com")
    AwsHTTP.http_headers_add(headers, "Other", "keep")
    AwsHTTP.http_headers_add(headers, "Host", "old2.com")
    @test AwsHTTP.http_headers_count(headers) == 3

    # Set replaces all existing "Host" headers
    @test AwsHTTP.http_headers_set(headers, "Host", "new.com") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 2  # "Host" + "Other"
    @test AwsHTTP.http_headers_get(headers, "Host") == "new.com"
    @test AwsHTTP.http_headers_get(headers, "Other") == "keep"

    # Set a new header (no existing to replace)
    @test AwsHTTP.http_headers_set(headers, "New-Header", "value") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 3
    @test AwsHTTP.http_headers_get(headers, "New-Header") == "value"
end

@testset "HttpHeaders erase" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "A", "1")
    AwsHTTP.http_headers_add(headers, "B", "2")
    AwsHTTP.http_headers_add(headers, "A", "3")
    AwsHTTP.http_headers_add(headers, "C", "4")
    @test AwsHTTP.http_headers_count(headers) == 4

    # Erase all "A" headers
    @test AwsHTTP.http_headers_erase(headers, "A") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 2
    @test AwsHTTP.http_headers_has(headers, "A") == false
    @test AwsHTTP.http_headers_get(headers, "B") == "2"
    @test AwsHTTP.http_headers_get(headers, "C") == "4"

    # Erase nonexistent
    @test AwsHTTP.http_headers_erase(headers, "A") == AwsIO.OP_ERR
end

@testset "HttpHeaders erase_value" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "X", "one")
    AwsHTTP.http_headers_add(headers, "X", "two")
    AwsHTTP.http_headers_add(headers, "X", "three")
    @test AwsHTTP.http_headers_count(headers) == 3

    # Erase specific value
    @test AwsHTTP.http_headers_erase_value(headers, "X", "two") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 2
    vals = AwsHTTP.http_headers_get_all(headers, "X")
    @test vals == "one, three"

    # Erase nonexistent value
    @test AwsHTTP.http_headers_erase_value(headers, "X", "two") == AwsIO.OP_ERR  # already removed
    @test AwsHTTP.http_headers_erase_value(headers, "Y", "val") == AwsIO.OP_ERR  # no such name
end

@testset "HttpHeaders erase_index" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "A", "1")
    AwsHTTP.http_headers_add(headers, "B", "2")
    AwsHTTP.http_headers_add(headers, "C", "3")

    # Erase middle (0-based index 1)
    @test AwsHTTP.http_headers_erase_index(headers, 1) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_count(headers) == 2
    @test AwsHTTP.http_headers_get_index(headers, 0).name == "A"
    @test AwsHTTP.http_headers_get_index(headers, 1).name == "C"

    # Invalid index
    @test AwsHTTP.http_headers_erase_index(headers, -1) == AwsIO.OP_ERR
    @test AwsHTTP.http_headers_erase_index(headers, 2) == AwsIO.OP_ERR
end

@testset "HttpHeaders clear" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "A", "1")
    AwsHTTP.http_headers_add(headers, "B", "2")
    @test AwsHTTP.http_headers_count(headers) == 2

    AwsHTTP.http_headers_clear(headers)
    @test AwsHTTP.http_headers_count(headers) == 0
    @test AwsHTTP.http_headers_has(headers, "A") == false
end

@testset "HttpHeaders pseudo-header ordering" begin
    headers = AwsHTTP.http_headers_new()

    # Add regular headers first
    AwsHTTP.http_headers_add(headers, "Host", "example.com")
    AwsHTTP.http_headers_add(headers, "Accept", "text/html")

    # Adding pseudo-header should go to front
    AwsHTTP.http_headers_add(headers, ":method", "GET")
    @test AwsHTTP.http_headers_count(headers) == 3
    @test AwsHTTP.http_headers_get_index(headers, 0).name == ":method"
    @test AwsHTTP.http_headers_get_index(headers, 1).name == "Host"
    @test AwsHTTP.http_headers_get_index(headers, 2).name == "Accept"

    # Adding another pseudo-header also goes to front
    AwsHTTP.http_headers_add(headers, ":scheme", "https")
    @test AwsHTTP.http_headers_get_index(headers, 0).name == ":scheme"
    @test AwsHTTP.http_headers_get_index(headers, 1).name == ":method"

    # When only pseudo-headers exist, new ones append to end
    headers2 = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers2, ":method", "GET")
    AwsHTTP.http_headers_add(headers2, ":path", "/")
    @test AwsHTTP.http_headers_get_index(headers2, 0).name == ":method"
    @test AwsHTTP.http_headers_get_index(headers2, 1).name == ":path"
end

@testset "H2 pseudo-header accessors" begin
    headers = AwsHTTP.http_headers_new()

    # Set and get request pseudo-headers
    @test AwsHTTP.http2_headers_set_request_method(headers, "GET") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_request_method(headers) == "GET"

    @test AwsHTTP.http2_headers_set_request_scheme(headers, "https") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_request_scheme(headers) == "https"

    @test AwsHTTP.http2_headers_set_request_authority(headers, "example.com") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_request_authority(headers) == "example.com"

    @test AwsHTTP.http2_headers_set_request_path(headers, "/index.html") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_request_path(headers) == "/index.html"

    # Overwrite existing
    @test AwsHTTP.http2_headers_set_request_method(headers, "POST") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_request_method(headers) == "POST"

    # Response status
    headers2 = AwsHTTP.http_headers_new()
    @test AwsHTTP.http2_headers_set_response_status(headers2, 200) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_response_status(headers2) == 200

    @test AwsHTTP.http2_headers_set_response_status(headers2, 404) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http2_headers_get_response_status(headers2) == 404

    # Status padded to 3 digits
    @test AwsHTTP.http2_headers_set_response_status(headers2, 1) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_headers_get(headers2, ":status") == "001"
    @test AwsHTTP.http2_headers_get_response_status(headers2) == 1

    # Invalid status
    @test AwsHTTP.http2_headers_set_response_status(headers2, -1) == AwsIO.OP_ERR
    @test AwsHTTP.http2_headers_set_response_status(headers2, 1000) == AwsIO.OP_ERR
end

@testset "Http2PrioritySettings" begin
    p = AwsHTTP.Http2PrioritySettings()
    @test p.stream_dependency == 0
    @test p.stream_dependency_exclusive == false
    @test p.weight == 16

    p2 = AwsHTTP.Http2PrioritySettings(UInt32(5), true, UInt16(256))
    @test p2.stream_dependency == 5
    @test p2.stream_dependency_exclusive == true
    @test p2.weight == 256
end

@testset "HttpStreamMetrics" begin
    m = AwsHTTP.HttpStreamMetrics()
    @test m.send_start_timestamp_ns == -1
    @test m.send_end_timestamp_ns == -1
    @test m.sending_duration_ns == -1
    @test m.receive_start_timestamp_ns == -1
    @test m.receive_end_timestamp_ns == -1
    @test m.receiving_duration_ns == -1
    @test m.stream_id == 0

    m2 = AwsHTTP.HttpStreamMetrics(100, 200, 100, 300, 400, 100, UInt32(1))
    @test m2.send_start_timestamp_ns == 100
    @test m2.sending_duration_ns == 100
    @test m2.stream_id == 1
end

@testset "HttpMessage request creation" begin
    req = AwsHTTP.http_message_new_request()
    @test AwsHTTP.http_message_is_request(req) == true
    @test AwsHTTP.http_message_is_response(req) == false
    @test AwsHTTP.http_message_get_protocol_version(req) == AwsHTTP.HttpVersion.HTTP_1_1
    @test AwsHTTP.http_message_get_header_count(req) == 0
    @test AwsHTTP.http_message_get_body_stream(req) === nothing

    # Method not set initially
    @test AwsHTTP.http_message_get_request_method(req) === nothing
    @test AwsHTTP.http_message_get_request_path(req) === nothing
end

@testset "HttpMessage response creation" begin
    resp = AwsHTTP.http_message_new_response()
    @test AwsHTTP.http_message_is_request(resp) == false
    @test AwsHTTP.http_message_is_response(resp) == true
    @test AwsHTTP.http_message_get_protocol_version(resp) == AwsHTTP.HttpVersion.HTTP_1_1
    @test AwsHTTP.http_message_get_response_status(resp) === nothing  # not set
end

@testset "HttpMessage request with headers" begin
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "Host", "example.com")
    AwsHTTP.http_headers_add(headers, "Accept", "text/html")

    req = AwsHTTP.http_message_new_request_with_headers(headers)
    @test AwsHTTP.http_message_get_header_count(req) == 2
    @test AwsHTTP.http_headers_get(AwsHTTP.http_message_get_headers(req), "Host") == "example.com"
end

@testset "HttpMessage H1 request method/path" begin
    req = AwsHTTP.http_message_new_request()

    # Set and get method
    @test AwsHTTP.http_message_set_request_method(req, "GET") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_request_method(req) == "GET"

    # Overwrite method
    @test AwsHTTP.http_message_set_request_method(req, "POST") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_request_method(req) == "POST"

    # Set and get path
    @test AwsHTTP.http_message_set_request_path(req, "/api/v1") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_request_path(req) == "/api/v1"

    # Cannot get request fields from response
    resp = AwsHTTP.http_message_new_response()
    @test AwsHTTP.http_message_get_request_method(resp) === nothing
    @test AwsHTTP.http_message_get_request_path(resp) === nothing
    @test AwsHTTP.http_message_set_request_method(resp, "GET") == AwsIO.OP_ERR
end

@testset "HttpMessage H1 response status" begin
    resp = AwsHTTP.http_message_new_response()

    @test AwsHTTP.http_message_set_response_status(resp, 200) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_response_status(resp) == 200

    @test AwsHTTP.http_message_set_response_status(resp, 404) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_response_status(resp) == 404

    # Invalid status codes
    @test AwsHTTP.http_message_set_response_status(resp, -1) == AwsIO.OP_ERR
    @test AwsHTTP.http_message_set_response_status(resp, 1000) == AwsIO.OP_ERR

    # Cannot set response status on request
    req = AwsHTTP.http_message_new_request()
    @test AwsHTTP.http_message_set_response_status(req, 200) == AwsIO.OP_ERR
    @test AwsHTTP.http_message_get_response_status(req) === nothing
end

@testset "HttpMessage H2 request method/path via pseudo-headers" begin
    req = AwsHTTP.http2_message_new_request()
    @test AwsHTTP.http_message_get_protocol_version(req) == AwsHTTP.HttpVersion.HTTP_2

    @test AwsHTTP.http_message_set_request_method(req, "GET") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_request_method(req) == "GET"
    # Stored as :method pseudo-header
    @test AwsHTTP.http_headers_get(AwsHTTP.http_message_get_headers(req), ":method") == "GET"

    @test AwsHTTP.http_message_set_request_path(req, "/index.html") == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_request_path(req) == "/index.html"
    @test AwsHTTP.http_headers_get(AwsHTTP.http_message_get_headers(req), ":path") == "/index.html"
end

@testset "HttpMessage H2 response status via pseudo-headers" begin
    resp = AwsHTTP.http2_message_new_response()
    @test AwsHTTP.http_message_get_protocol_version(resp) == AwsHTTP.HttpVersion.HTTP_2

    @test AwsHTTP.http_message_set_response_status(resp, 200) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_response_status(resp) == 200
    @test AwsHTTP.http_headers_get(AwsHTTP.http_message_get_headers(resp), ":status") == "200"
end

@testset "HttpMessage body stream" begin
    req = AwsHTTP.http_message_new_request()
    @test AwsHTTP.http_message_get_body_stream(req) === nothing

    body = IOBuffer("hello world")
    AwsHTTP.http_message_set_body_stream(req, body)
    @test AwsHTTP.http_message_get_body_stream(req) === body

    AwsHTTP.http_message_set_body_stream(req, nothing)
    @test AwsHTTP.http_message_get_body_stream(req) === nothing
end

@testset "HttpMessage convenience header methods" begin
    req = AwsHTTP.http_message_new_request()

    @test AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("A", "1")) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("B", "2")) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_header_count(req) == 2

    h = AwsHTTP.http_message_get_header(req, 0)
    @test h !== nothing
    @test h.name == "A"
    @test h.value == "1"

    @test AwsHTTP.http_message_erase_header(req, 0) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_header_count(req) == 1
    @test AwsHTTP.http_message_get_header(req, 0).name == "B"

    arr = [AwsHTTP.HttpHeader("C", "3"), AwsHTTP.HttpHeader("D", "4")]
    @test AwsHTTP.http_message_add_header_array(req, arr) == AwsIO.OP_SUCCESS
    @test AwsHTTP.http_message_get_header_count(req) == 3
end

@testset "HttpMessage refcounting" begin
    msg = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_add_header(msg, AwsHTTP.HttpHeader("X", "Y"))

    acquired = AwsHTTP.http_message_acquire(msg)
    @test acquired === msg  # same object

    # Release once (refcount 2->1, should NOT destroy)
    AwsHTTP.http_message_release(msg)
    @test AwsHTTP.http_message_get_header_count(msg) == 1

    # Release again (refcount 1->0, cleans up)
    AwsHTTP.http_message_release(msg)
    @test AwsHTTP.http_message_get_body_stream(msg) === nothing
end

@testset "H1→H2 request conversion" begin
    h1_req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(h1_req, "GET")
    AwsHTTP.http_message_set_request_path(h1_req, "/index.html")
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Accept", "text/html"))
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Connection", "keep-alive"))
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Keep-Alive", "timeout=5"))

    h2_req = AwsHTTP.http2_message_new_from_http1(h1_req)
    @test h2_req !== nothing
    @test AwsHTTP.http_message_is_request(h2_req) == true
    @test AwsHTTP.http_message_get_protocol_version(h2_req) == AwsHTTP.HttpVersion.HTTP_2

    headers = AwsHTTP.http_message_get_headers(h2_req)

    # Pseudo-headers present
    @test AwsHTTP.http_headers_get(headers, ":method") == "GET"
    @test AwsHTTP.http_headers_get(headers, ":scheme") == "https"
    @test AwsHTTP.http_headers_get(headers, ":authority") == "example.com"
    @test AwsHTTP.http_headers_get(headers, ":path") == "/index.html"

    # Regular header preserved (lowercased)
    @test AwsHTTP.http_headers_get(headers, "accept") == "text/html"

    # Connection-specific headers removed
    @test AwsHTTP.http_headers_has(headers, "connection") == false
    @test AwsHTTP.http_headers_has(headers, "keep-alive") == false
    @test AwsHTTP.http_headers_has(headers, "host") == false
end

@testset "H1→H2 request conversion with scheme override" begin
    h1_req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(h1_req, "GET")
    AwsHTTP.http_message_set_request_path(h1_req, "/")
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Host", "example.com"))

    h2_req = AwsHTTP.http2_message_new_from_http1_with_scheme(h1_req, "http")
    @test h2_req !== nothing
    @test AwsHTTP.http_headers_get(AwsHTTP.http_message_get_headers(h2_req), ":scheme") == "http"
end

@testset "H1→H2 response conversion" begin
    h1_resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(h1_resp, 200)
    AwsHTTP.http_message_add_header(h1_resp, AwsHTTP.HttpHeader("Content-Type", "text/html"))
    AwsHTTP.http_message_add_header(h1_resp, AwsHTTP.HttpHeader("Connection", "close"))
    AwsHTTP.http_message_add_header(h1_resp, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))

    h2_resp = AwsHTTP.http2_message_new_from_http1(h1_resp)
    @test h2_resp !== nothing
    @test AwsHTTP.http_message_is_response(h2_resp) == true

    headers = AwsHTTP.http_message_get_headers(h2_resp)
    @test AwsHTTP.http2_headers_get_response_status(headers) == 200
    @test AwsHTTP.http_headers_get(headers, "content-type") == "text/html"

    # Connection-specific removed
    @test AwsHTTP.http_headers_has(headers, "connection") == false
    @test AwsHTTP.http_headers_has(headers, "transfer-encoding") == false
end

@testset "H1→H2 conversion preserves TE: trailers" begin
    h1_req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(h1_req, "GET")
    AwsHTTP.http_message_set_request_path(h1_req, "/")
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("TE", "trailers"))

    h2_req = AwsHTTP.http2_message_new_from_http1(h1_req)
    @test h2_req !== nothing
    @test AwsHTTP.http_headers_get(AwsHTTP.http_message_get_headers(h2_req), "te") == "trailers"
end

@testset "H1→H2 conversion body stream" begin
    h1_req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(h1_req, "POST")
    AwsHTTP.http_message_set_request_path(h1_req, "/upload")
    AwsHTTP.http_message_add_header(h1_req, AwsHTTP.HttpHeader("Host", "example.com"))
    body = IOBuffer("request body")
    AwsHTTP.http_message_set_body_stream(h1_req, body)

    h2_req = AwsHTTP.http2_message_new_from_http1(h1_req)
    @test h2_req !== nothing
    @test AwsHTTP.http_message_get_body_stream(h2_req) === body
end

# ─── Phase 2: HTTP/1.1 encoder ───

# Helper: create an IOBuffer with a max size for encoder output
function make_output_buf(maxsize::Int=16384)
    buf = IOBuffer(maxsize=maxsize)
    return buf
end

# Helper: encode a full message and return the encoded bytes as a string
function encode_message_to_string(encoder, encoder_msg)
    buf = make_output_buf()
    AwsHTTP.h1_encoder_start_message!(encoder, encoder_msg)
    @test AwsHTTP.h1_encoder_process!(encoder, buf) == AwsIO.OP_SUCCESS
    return String(take!(buf))
end

@testset "HTTP string validation - is_http_token" begin
    # Valid tokens
    @test AwsHTTP.is_http_token("GET") == true
    @test AwsHTTP.is_http_token("Content-Type") == true
    @test AwsHTTP.is_http_token("X-Custom-Header") == true
    @test AwsHTTP.is_http_token("accept") == true
    @test AwsHTTP.is_http_token("host") == true
    @test AwsHTTP.is_http_token("!#\$%&'*+-.^_`|~") == true  # all special tchar
    @test AwsHTTP.is_http_token("abc123") == true

    # Invalid tokens
    @test AwsHTTP.is_http_token("") == false              # empty
    @test AwsHTTP.is_http_token("G@T") == false            # @ is not tchar
    @test AwsHTTP.is_http_token("Host:") == false          # colon is not tchar
    @test AwsHTTP.is_http_token("name value") == false     # space is not tchar
    @test AwsHTTP.is_http_token("Line-\r\n-Folds") == false # CR/LF not tchar
    @test AwsHTTP.is_http_token("bad\x00name") == false    # null byte
    @test AwsHTTP.is_http_token("(parens)") == false       # parens not tchar
    @test AwsHTTP.is_http_token("a/b") == false            # slash not tchar
end

@testset "HTTP string validation - is_http_field_value" begin
    # Valid field values
    @test AwsHTTP.is_http_field_value("") == true           # empty is valid
    @test AwsHTTP.is_http_field_value("text/html") == true
    @test AwsHTTP.is_http_field_value("hello world") == true  # SP allowed in middle
    @test AwsHTTP.is_http_field_value("a\tb") == true         # HTAB allowed in middle
    @test AwsHTTP.is_http_field_value("value") == true
    @test AwsHTTP.is_http_field_value("application/json; charset=utf-8") == true

    # Invalid field values
    @test AwsHTTP.is_http_field_value(" leading") == false   # leading SP
    @test AwsHTTP.is_http_field_value("trailing ") == false  # trailing SP
    @test AwsHTTP.is_http_field_value("\tleading") == false   # leading HTAB
    @test AwsHTTP.is_http_field_value("trailing\t") == false  # trailing HTAB
    @test AwsHTTP.is_http_field_value("bad\r\nvalue") == false  # CR/LF
    @test AwsHTTP.is_http_field_value("bad\x00value") == false  # null byte
    @test AwsHTTP.is_http_field_value("item1,\r\n item2") == false  # obs-fold
end

@testset "HTTP string validation - is_http_request_target" begin
    # Valid request targets
    @test AwsHTTP.is_http_request_target("/") == true
    @test AwsHTTP.is_http_request_target("/index.html") == true
    @test AwsHTTP.is_http_request_target("/api/v1/users?page=1") == true
    @test AwsHTTP.is_http_request_target("*") == true
    @test AwsHTTP.is_http_request_target("http://example.com/path") == true

    # Invalid request targets
    @test AwsHTTP.is_http_request_target("") == false         # empty
    @test AwsHTTP.is_http_request_target("/\r\n/index.html") == false  # CR/LF
    @test AwsHTTP.is_http_request_target("/ /path") == false  # space
    @test AwsHTTP.is_http_request_target("/\x00") == false     # null byte
end

@testset "H1EncoderState enum" begin
    @test UInt8(AwsHTTP.H1EncoderState.INIT) == 0
    @test UInt8(AwsHTTP.H1EncoderState.HEAD) == 1
    @test UInt8(AwsHTTP.H1EncoderState.UNCHUNKED_BODY_STREAM) == 2
    @test UInt8(AwsHTTP.H1EncoderState.CHUNKED_BODY_STREAM) == 3
    @test UInt8(AwsHTTP.H1EncoderState.CHUNKED_BODY_STREAM_LAST_CHUNK) == 4
    @test UInt8(AwsHTTP.H1EncoderState.CHUNK_NEXT) == 5
    @test UInt8(AwsHTTP.H1EncoderState.CHUNK_LINE) == 6
    @test UInt8(AwsHTTP.H1EncoderState.CHUNK_BODY) == 7
    @test UInt8(AwsHTTP.H1EncoderState.CHUNK_END) == 8
    @test UInt8(AwsHTTP.H1EncoderState.CHUNK_TRAILER) == 9
    @test UInt8(AwsHTTP.H1EncoderState.DONE) == 10
end

@testset "H1Chunk creation and lifecycle" begin
    # Create a chunk with data
    data = IOBuffer("hello world")
    chunk = AwsHTTP.h1_chunk_new(data, 11)
    @test chunk.data_size == 11
    @test chunk.data === data
    @test !isempty(chunk.chunk_line)
    # chunk_line should be "B\r\n" (11 in hex)
    @test String(chunk.chunk_line) == "B\r\n"

    # Final chunk (zero-length)
    final_chunk = AwsHTTP.h1_chunk_new(nothing, 0)
    @test final_chunk.data_size == 0
    @test String(final_chunk.chunk_line) == "0\r\n"

    # Chunk with extensions
    ext_chunk = AwsHTTP.h1_chunk_new(nothing, 16, extensions=[
        AwsHTTP.H1ChunkExtension("name", "val")
    ])
    @test String(ext_chunk.chunk_line) == "10;name=val\r\n"

    # Callback lifecycle
    called = Ref(false)
    cb_chunk = AwsHTTP.h1_chunk_new(nothing, 0, on_complete=(s, e, u) -> (called[] = true))
    AwsHTTP.h1_chunk_complete_and_destroy!(cb_chunk, 0)
    @test called[] == true
end

@testset "H1Trailer creation" begin
    # Valid trailer
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, "X-Checksum", "abc123")
    trailer = AwsHTTP.h1_trailer_new(headers)
    @test trailer !== nothing
    @test String(trailer.trailer_data) == "X-Checksum: abc123\r\n\r\n"

    # Forbidden trailer header (Content-Length)
    bad_headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(bad_headers, "Content-Length", "100")
    @test AwsHTTP.h1_trailer_new(bad_headers) === nothing

    # Forbidden trailer header (Transfer-Encoding)
    bad_headers2 = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(bad_headers2, "Transfer-Encoding", "chunked")
    @test AwsHTTP.h1_trailer_new(bad_headers2) === nothing

    # Forbidden trailer header (Set-Cookie)
    bad_headers3 = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(bad_headers3, "Set-Cookie", "a=b")
    @test AwsHTTP.h1_trailer_new(bad_headers3) === nothing
end

@testset "H1EncoderMessage - init from request (basic GET)" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_SUCCESS
    @test !msg.has_chunked_encoding_header
    @test !msg.has_connection_close_header
    @test msg.content_length == 0

    head = String(msg.outgoing_head_buf)
    @test startswith(head, "GET / HTTP/1.1\r\n")
    @test occursin("Host: amazon.com\r\n", head)
    @test endswith(head, "\r\n\r\n")

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - init from request with Content-Length" begin
    body = IOBuffer("write more tests")
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Content-Length", "16"))
    AwsHTTP.http_message_set_body_stream(req, body)

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_SUCCESS
    @test !msg.has_chunked_encoding_header
    @test !msg.has_connection_close_header
    @test msg.content_length == 16

    head = String(msg.outgoing_head_buf)
    @test startswith(head, "PUT / HTTP/1.1\r\n")

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - Transfer-Encoding: chunked" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_SUCCESS
    @test msg.has_chunked_encoding_header
    @test !msg.has_connection_close_header
    @test msg.content_length == 0

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - Transfer-Encoding with multiple encodings" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "gzip"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_SUCCESS
    @test msg.has_chunked_encoding_header

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - case insensitive header names" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("traNsfeR-EncODIng", "chunked"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_SUCCESS
    @test msg.has_chunked_encoding_header

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - chunked in comma-separated value" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "gzip, chunked"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_SUCCESS
    @test msg.has_chunked_encoding_header

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - rejects invalid requests" begin
    # Bad method (non-token characters)
    msg = AwsHTTP.H1EncoderMessage()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "G@T")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_ERR

    # Missing method
    msg2 = AwsHTTP.H1EncoderMessage()
    req2 = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_path(req2, "/")
    AwsHTTP.http_message_add_header(req2, AwsHTTP.HttpHeader("Host", "amazon.com"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg2, req2) == AwsIO.OP_ERR

    # Bad path (contains CRLF)
    msg3 = AwsHTTP.H1EncoderMessage()
    req3 = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req3, "GET")
    AwsHTTP.http_message_set_request_path(req3, "/\r\n/index.html")
    AwsHTTP.http_message_add_header(req3, AwsHTTP.HttpHeader("Host", "amazon.com"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg3, req3) == AwsIO.OP_ERR

    # Missing path
    msg4 = AwsHTTP.H1EncoderMessage()
    req4 = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req4, "GET")
    AwsHTTP.http_message_add_header(req4, AwsHTTP.HttpHeader("Host", "amazon.com"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg4, req4) == AwsIO.OP_ERR

    # Bad header name
    msg5 = AwsHTTP.H1EncoderMessage()
    req5 = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req5, "GET")
    AwsHTTP.http_message_set_request_path(req5, "/")
    AwsHTTP.http_message_add_header(req5, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req5, AwsHTTP.HttpHeader("Line-\r\n-Folds", "bad"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg5, req5) == AwsIO.OP_ERR

    # Bad header value
    msg6 = AwsHTTP.H1EncoderMessage()
    req6 = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req6, "GET")
    AwsHTTP.http_message_set_request_path(req6, "/")
    AwsHTTP.http_message_add_header(req6, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req6, AwsHTTP.HttpHeader("X-Bad", "item1,\r\n item2"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg6, req6) == AwsIO.OP_ERR
end

@testset "H1EncoderMessage - rejects Transfer-Encoding without chunked" begin
    msg = AwsHTTP.H1EncoderMessage()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "gzip"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_ERR
end

@testset "H1EncoderMessage - rejects chunked not as final encoding" begin
    # chunked must be the last encoding; "chunked,gzip" is invalid
    msg = AwsHTTP.H1EncoderMessage()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked,gzip"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_ERR
end

@testset "H1EncoderMessage - rejects chunked + Content-Length" begin
    msg = AwsHTTP.H1EncoderMessage()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Content-Length", "16"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_ERR
end

@testset "H1EncoderMessage - rejects chunked not ending last across headers" begin
    # Two TE headers: chunked then gzip = invalid (chunked must be last)
    msg = AwsHTTP.H1EncoderMessage()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "PUT")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "amazon.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "gzip"))
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_ERR
end

@testset "H1EncoderMessage - init from response" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 200)
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Content-Type", "text/html"))
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Content-Length", "5"))
    AwsHTTP.http_message_set_body_stream(resp, IOBuffer("hello"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_response!(msg, resp) == AwsIO.OP_SUCCESS

    head = String(msg.outgoing_head_buf)
    @test startswith(head, "HTTP/1.1 200 OK\r\n")
    @test occursin("Content-Type: text/html\r\n", head)
    @test occursin("Content-Length: 5\r\n", head)
    @test endswith(head, "\r\n\r\n")
    @test msg.content_length == 5
    @test !msg.is_switching_protocols

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - response 101 Switching Protocols" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 101)
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Upgrade", "websocket"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_response!(msg, resp) == AwsIO.OP_SUCCESS
    @test msg.is_switching_protocols

    head = String(msg.outgoing_head_buf)
    @test startswith(head, "HTTP/1.1 101 Switching Protocols\r\n")

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1EncoderMessage - response 204 No Content forbids body headers" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 204)
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Content-Length", "100"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_response!(msg, resp) == AwsIO.OP_ERR
end

@testset "H1EncoderMessage - response Connection: close detection" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 200)
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Connection", "close"))

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_response!(msg, resp) == AwsIO.OP_SUCCESS
    @test msg.has_connection_close_header

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

@testset "H1Encoder - lifecycle" begin
    encoder = AwsHTTP.h1_encoder_init()
    @test encoder.state == AwsHTTP.H1EncoderState.INIT
    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)

    AwsHTTP.h1_encoder_clean_up!(encoder)
    @test encoder.state == AwsHTTP.H1EncoderState.INIT
    @test encoder.message === nothing
end

@testset "H1Encoder - process without message returns error" begin
    encoder = AwsHTTP.h1_encoder_init()
    buf = make_output_buf()
    @test AwsHTTP.h1_encoder_process!(encoder, buf) == AwsIO.OP_ERR
end

@testset "H1Encoder - encode GET request (no body)" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/index.html")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Accept", "*/*"))

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req)

    encoder = AwsHTTP.h1_encoder_init()
    result = encode_message_to_string(encoder, msg)

    @test result == "GET /index.html HTTP/1.1\r\nHost: example.com\r\nAccept: */*\r\n\r\n"
    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)
end

@testset "H1Encoder - encode POST request with body" begin
    body_content = "hello world!"
    body = IOBuffer(body_content)

    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "POST")
    AwsHTTP.http_message_set_request_path(req, "/upload")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Content-Length", string(length(body_content))))
    AwsHTTP.http_message_set_body_stream(req, body)

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req)

    encoder = AwsHTTP.h1_encoder_init()
    result = encode_message_to_string(encoder, msg)

    expected = "POST /upload HTTP/1.1\r\n" *
               "Host: example.com\r\n" *
               "Content-Length: 12\r\n" *
               "\r\n" *
               "hello world!"
    @test result == expected
    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)
end

@testset "H1Encoder - encode response" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 200)
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Content-Type", "text/plain"))
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Content-Length", "2"))
    AwsHTTP.http_message_set_body_stream(resp, IOBuffer("OK"))

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_response!(msg, resp)

    encoder = AwsHTTP.h1_encoder_init()
    result = encode_message_to_string(encoder, msg)

    expected = "HTTP/1.1 200 OK\r\n" *
               "Content-Type: text/plain\r\n" *
               "Content-Length: 2\r\n" *
               "\r\n" *
               "OK"
    @test result == expected
end

@testset "H1Encoder - encode 404 response" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 404)

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_response!(msg, resp)

    encoder = AwsHTTP.h1_encoder_init()
    result = encode_message_to_string(encoder, msg)

    @test startswith(result, "HTTP/1.1 404 Not Found\r\n")
end

@testset "H1Encoder - chunked body stream (auto-chunking)" begin
    body = IOBuffer("Hello, World!")  # 13 bytes

    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "POST")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))
    AwsHTTP.http_message_set_body_stream(req, body)

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req)

    encoder = AwsHTTP.h1_encoder_init()
    buf = make_output_buf()
    AwsHTTP.h1_encoder_start_message!(encoder, msg)
    @test AwsHTTP.h1_encoder_process!(encoder, buf) == AwsIO.OP_SUCCESS

    result = String(take!(buf))

    # Should contain the request line and headers
    @test occursin("POST / HTTP/1.1\r\n", result)
    @test occursin("Transfer-Encoding: chunked\r\n", result)
    # Should contain the body as a chunk with hex length
    @test occursin("Hello, World!", result)
    # Should end with last chunk marker and trailer CRLF
    @test occursin("0\r\n\r\n", result)
    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)
end

@testset "H1Encoder - manual chunk API" begin
    chunks = AwsHTTP.H1Chunk[]

    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "POST")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req, pending_chunk_list=chunks)

    encoder = AwsHTTP.h1_encoder_init()
    buf = make_output_buf()
    AwsHTTP.h1_encoder_start_message!(encoder, msg)

    # Process - should encode head then wait for chunks
    @test AwsHTTP.h1_encoder_process!(encoder, buf) == AwsIO.OP_SUCCESS
    @test AwsHTTP.h1_encoder_is_message_in_progress(encoder)
    @test AwsHTTP.h1_encoder_is_waiting_for_chunks(encoder)

    # Add a data chunk
    chunk1_data = IOBuffer("first chunk")
    chunk1 = AwsHTTP.h1_chunk_new(chunk1_data, 11)
    push!(msg.pending_chunk_list, chunk1)

    # Process the chunk
    @test AwsHTTP.h1_encoder_process!(encoder, buf) == AwsIO.OP_SUCCESS
    @test AwsHTTP.h1_encoder_is_waiting_for_chunks(encoder)

    # Add final chunk (zero-length)
    final = AwsHTTP.h1_chunk_new(nothing, 0)
    push!(msg.pending_chunk_list, final)

    # Process final chunk
    @test AwsHTTP.h1_encoder_process!(encoder, buf) == AwsIO.OP_SUCCESS
    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)

    result = String(take!(buf))
    @test occursin("POST / HTTP/1.1\r\n", result)
    @test occursin("first chunk", result)
    @test occursin("B\r\n", result)  # hex 11
    @test occursin("0\r\n", result)  # final chunk
end

@testset "H1Encoder - fragmented output buffer (resume encoding)" begin
    body_content = "abcdefghij"  # 10 bytes
    body = IOBuffer(body_content)

    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Content-Length", "10"))
    AwsHTTP.http_message_set_body_stream(req, body)

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req)

    encoder = AwsHTTP.h1_encoder_init()
    AwsHTTP.h1_encoder_start_message!(encoder, msg)

    # Use a very small buffer to force fragmentation
    all_bytes = UInt8[]
    while AwsHTTP.h1_encoder_is_message_in_progress(encoder)
        small_buf = IOBuffer(maxsize=20)
        @test AwsHTTP.h1_encoder_process!(encoder, small_buf) == AwsIO.OP_SUCCESS
        append!(all_bytes, take!(small_buf))
    end

    result = String(all_bytes)
    expected = "GET / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 10\r\n\r\nabcdefghij"
    @test result == expected
end

@testset "H1Encoder - HEAD request (no body)" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "HEAD")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req)

    encoder = AwsHTTP.h1_encoder_init()
    result = encode_message_to_string(encoder, msg)

    @test result == "HEAD / HTTP/1.1\r\nHost: example.com\r\n\r\n"
end

@testset "H1Encoder - DELETE request" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "DELETE")
    AwsHTTP.http_message_set_request_path(req, "/resource/42")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req)

    encoder = AwsHTTP.h1_encoder_init()
    result = encode_message_to_string(encoder, msg)

    @test result == "DELETE /resource/42 HTTP/1.1\r\nHost: example.com\r\n\r\n"
end

@testset "H1Encoder - rejects Content-Length with no body stream" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "POST")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Content-Length", "100"))
    # No body stream set!

    msg = AwsHTTP.H1EncoderMessage()
    @test AwsHTTP.h1_encoder_message_init_from_request!(msg, req) == AwsIO.OP_ERR
end

@testset "H1Encoder - start message fails if already in progress" begin
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))

    msg1 = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg1, req)
    msg2 = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg2, req)

    encoder = AwsHTTP.h1_encoder_init()
    @test AwsHTTP.h1_encoder_start_message!(encoder, msg1) == AwsIO.OP_SUCCESS
    @test AwsHTTP.h1_encoder_start_message!(encoder, msg2) == AwsIO.OP_ERR

    # Process msg1 to completion
    buf = make_output_buf()
    AwsHTTP.h1_encoder_process!(encoder, buf)
    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)

    # Now we can start msg2
    @test AwsHTTP.h1_encoder_start_message!(encoder, msg2) == AwsIO.OP_SUCCESS
end

@testset "H1Encoder - manual chunk with trailer" begin
    chunks = AwsHTTP.H1Chunk[]

    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "POST")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Transfer-Encoding", "chunked"))

    msg = AwsHTTP.H1EncoderMessage()
    AwsHTTP.h1_encoder_message_init_from_request!(msg, req, pending_chunk_list=chunks)

    # Set up trailer
    trailer_headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(trailer_headers, "X-Checksum", "abc123")
    msg.trailer = AwsHTTP.h1_trailer_new(trailer_headers)
    @test msg.trailer !== nothing

    encoder = AwsHTTP.h1_encoder_init()
    buf = make_output_buf()
    AwsHTTP.h1_encoder_start_message!(encoder, msg)

    # Process head
    AwsHTTP.h1_encoder_process!(encoder, buf)

    # Add data + final chunk
    push!(msg.pending_chunk_list, AwsHTTP.h1_chunk_new(IOBuffer("data"), 4))
    AwsHTTP.h1_encoder_process!(encoder, buf)
    push!(msg.pending_chunk_list, AwsHTTP.h1_chunk_new(nothing, 0))
    AwsHTTP.h1_encoder_process!(encoder, buf)

    @test !AwsHTTP.h1_encoder_is_message_in_progress(encoder)

    result = String(take!(buf))
    @test occursin("X-Checksum: abc123\r\n", result)
end

@testset "H1Encoder - response 304 ignores body headers" begin
    resp = AwsHTTP.http_message_new_response()
    AwsHTTP.http_message_set_response_status(resp, 304)
    AwsHTTP.http_message_add_header(resp, AwsHTTP.HttpHeader("Content-Length", "100"))

    msg = AwsHTTP.H1EncoderMessage()
    # 304 responses should have body_headers_ignored automatically
    @test AwsHTTP.h1_encoder_message_init_from_response!(msg, resp) == AwsIO.OP_SUCCESS
    # content_length should be forced to 0
    @test msg.content_length == 0

    AwsHTTP.h1_encoder_message_clean_up!(msg)
end

# ─── Phase 3: HTTP/1.1 Decoder ───

using Random

# Test helper: mutable state for decoder callbacks
mutable struct TestDecoderState
    requests::Vector{Tuple{AwsHTTP.HttpMethod.T, String, String}}
    responses::Vector{Int}
    headers::Vector{Tuple{AwsHTTP.HttpHeaderName.T, String, String}}
    body_data::Vector{UInt8}
    body_finished::Bool
    done_count::Int
end
TestDecoderState() = TestDecoderState([], [], [], UInt8[], false, 0)

_test_on_request(method_enum, method_str, uri, ud) = (push!(ud.requests, (method_enum, method_str, uri)); AwsIO.OP_SUCCESS)
_test_on_response(status_code, ud) = (push!(ud.responses, status_code); AwsIO.OP_SUCCESS)
_test_on_header(header, ud) = (push!(ud.headers, (header.name, header.name_data, header.value_data)); AwsIO.OP_SUCCESS)
function _test_on_body(data, finished, ud)
    append!(ud.body_data, data)
    ud.body_finished = finished
    return AwsIO.OP_SUCCESS
end
_test_on_done(ud) = (ud.done_count += 1; AwsIO.OP_SUCCESS)

_stub_on_request(me, ms, u, ud) = AwsIO.OP_SUCCESS
_stub_on_response(sc, ud) = AwsIO.OP_SUCCESS
_stub_on_header(h, ud) = AwsIO.OP_SUCCESS
_stub_on_body(d, f, ud) = AwsIO.OP_SUCCESS
_stub_on_done(ud) = AwsIO.OP_SUCCESS

function make_request_decoder(state=TestDecoderState())
    vtable = AwsHTTP.H1DecoderVtable(
        _test_on_header, _test_on_body, _test_on_request, _stub_on_response, _test_on_done)
    params = AwsHTTP.H1DecoderParams(1024, true, state, vtable)
    return AwsHTTP.h1_decoder_new(params), state
end

function make_response_decoder(state=TestDecoderState())
    vtable = AwsHTTP.H1DecoderVtable(
        _test_on_header, _test_on_body, _stub_on_request, _test_on_response, _test_on_done)
    params = AwsHTTP.H1DecoderParams(1024, false, state, vtable)
    return AwsHTTP.h1_decoder_new(params), state
end

@testset "H1Decoder - construction and destroy" begin
    dec, st = make_request_decoder()
    @test dec.is_decoding_requests == true
    @test dec.state == AwsHTTP.H1DecoderState.GETLINE_REQUEST
    AwsHTTP.h1_decoder_destroy!(dec)
    @test isempty(dec.scratch_space)

    dec2, _ = make_response_decoder()
    @test dec2.is_decoding_requests == false
    @test dec2.state == AwsHTTP.H1DecoderState.GETLINE_RESPONSE
    AwsHTTP.h1_decoder_destroy!(dec2)
end

@testset "H1DecodedHeader struct" begin
    h = AwsHTTP.H1DecodedHeader(AwsHTTP.HttpHeaderName.HOST, "Host", "example.com", "Host: example.com")
    @test h.name == AwsHTTP.HttpHeaderName.HOST
    @test h.name_data == "Host"
    @test h.value_data == "example.com"
    @test h.data == "Host: example.com"
end

@testset "H1Decoder - transfer encoding constants" begin
    @test AwsHTTP.HTTP_TRANSFER_ENCODING_CHUNKED == 1
    @test AwsHTTP.HTTP_TRANSFER_ENCODING_GZIP == 2
    @test AwsHTTP.HTTP_TRANSFER_ENCODING_DEFLATE == 4
    @test AwsHTTP.HTTP_TRANSFER_ENCODING_DEPRECATED_COMPRESS == 8
end

@testset "H1Decoder - typical request" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\nHost: amazon.com\r\nAccept-Language: fr\r\n\r\n"
    status, consumed = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test consumed == sizeof(msg)
    @test length(st.requests) == 1
    @test st.requests[1] == (AwsHTTP.HttpMethod.GET, "GET", "/")
    @test length(st.headers) == 2
    @test st.headers[1] == (AwsHTTP.HttpHeaderName.HOST, "Host", "amazon.com")
    @test st.headers[2] == (AwsHTTP.HttpHeaderName.UNKNOWN, "Accept-Language", "fr")
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - request with Content-Length body" begin
    dec, st = make_request_decoder()
    msg = "POST /data HTTP/1.1\r\nContent-Length: 11\r\n\r\nHello noob."
    status, consumed = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test consumed == sizeof(msg)
    @test st.requests[1][2] == "POST"
    @test st.requests[1][3] == "/data"
    @test String(st.body_data) == "Hello noob."
    @test st.body_finished == true
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - HEAD request (no body)" begin
    dec, st = make_request_decoder()
    msg = "HEAD /index.html HTTP/1.1\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test st.requests[1] == (AwsHTTP.HttpMethod.HEAD, "HEAD", "/index.html")
    @test st.done_count == 1
    @test isempty(st.body_data)
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - typical response" begin
    dec, st = make_response_decoder()
    msg = "HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\nHello noob."
    status, consumed = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test consumed == sizeof(msg)
    @test st.responses[1] == 200
    @test String(st.body_data) == "Hello noob."
    @test st.body_finished == true
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - response HTTP/1.0" begin
    dec, st = make_response_decoder()
    msg = "HTTP/1.0 404 Not Found\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test st.responses[1] == 404
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - response 204 (body headers forbidden)" begin
    dec, st = make_response_decoder()
    msg = "HTTP/1.1 204 No Content\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test st.done_count == 1
    @test isempty(st.body_data)
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - response 304 (body headers ignored)" begin
    dec, st = make_response_decoder()
    msg = "HTTP/1.1 304 Not Modified\r\nContent-Length: 100\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test st.done_count == 1
    @test isempty(st.body_data)
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - informational 1xx header block" begin
    block_seen = Ref(AwsHTTP.HttpHeaderBlock.MAIN)
    local the_dec
    vtable = AwsHTTP.H1DecoderVtable(
        _stub_on_header, _stub_on_body, _stub_on_request,
        (sc, ud) -> (block_seen[] = the_dec.header_block; AwsIO.OP_SUCCESS),
        _stub_on_done)
    the_dec = AwsHTTP.h1_decoder_new(AwsHTTP.H1DecoderParams(1024, false, nothing, vtable))
    status, _ = AwsHTTP.h1_decode!(the_dec, "HTTP/1.1 100 Continue\r\n\r\n")
    @test status == AwsIO.OP_SUCCESS
    @test block_seen[] == AwsHTTP.HttpHeaderBlock.INFORMATIONAL
    AwsHTTP.h1_decoder_destroy!(the_dec)
end

@testset "H1Decoder - header whitespace trimming" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\na-fake-header:      oh   what is this odd     whitespace      \r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test st.headers[1][3] == "oh   what is this odd     whitespace"
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - header value with colons" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\nDate: Wed, 21 Oct 2015 07:28:00 GMT\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test st.headers[1][3] == "Wed, 21 Oct 2015 07:28:00 GMT"
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - chunked body" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\nHost: amazon.com\r\nTransfer-Encoding: chunked\r\n\r\n" *
          "D\r\nHello, there \r\n" *
          "1c\r\nshould be a carriage return \r\n" *
          "9\r\nin\r\nhere.\r\n" *
          "0\r\n\r\n"
    status, consumed = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test consumed == sizeof(msg)
    @test String(st.body_data) == "Hello, there should be a carriage return in\r\nhere."
    @test st.body_finished == true
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - chunked body with trailers" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\nHost: amazon.com\r\nAccept-Language: fr\r\n" *
          "Transfer-Encoding:   chunked     \r\nTrailer: Expires\r\n\r\n" *
          "7\r\nMozilla\r\n9\r\nDeveloper\r\n7\r\nNetwork\r\n0\r\n" *
          "Expires: Wed, 21 Oct 2015 07:28:00 GMT\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test String(st.body_data) == "MozillaDeveloperNetwork"
    @test st.body_finished == true
    trailer_headers = filter(h -> h[2] == "Expires", st.headers)
    @test length(trailer_headers) >= 1
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - chunk extensions ignored" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\nHost: amazon.com\r\nTransfer-Encoding:   chunked     \r\n\r\n" *
          "7;ext-name=ext-value\r\nMozilla\r\n9\r\nDeveloper\r\n7\r\nNetwork\r\n" *
          "0\r\n\r\n"
    status, _ = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test String(st.body_data) == "MozillaDeveloperNetwork"
    @test st.done_count == 1
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - one byte at a time" begin
    dec, st = make_request_decoder()
    msg = Vector{UInt8}(codeunits("GET / HTTP/1.1\r\nHost: amazon.com\r\nAccept-Language: fr\r\n\r\n"))
    for i in 1:length(msg)
        status, consumed = AwsHTTP.h1_decode!(dec, @view msg[i:i])
        @test status == AwsIO.OP_SUCCESS
    end
    @test st.done_count == 1
    @test st.requests[1] == (AwsHTTP.HttpMethod.GET, "GET", "/")
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - random interval feeding" begin
    messages = [
        "GET / HTTP/1.1\r\nHost: amazon.com\r\nContent-Length: 6\r\n\r\n123456",
        "DELETE /file.html HTTP/1.1\r\n\r\n",
        "HEAD /index.html HTTP/1.1\r\n\r\n",
        "OPTIONS * HTTP/1.1\r\n\r\n",
        "POST / HTTP/1.1\r\nContent-Length: 13\r\n\r\nsay=Hi&to=Mom",
        "PUT /new.html HTTP/1.1\r\nContent-length: 16\r\n\r\n<p>New File</p>\n",
    ]
    rng = Random.MersenneTwister(42)
    for raw_msg in messages
        st = TestDecoderState()
        dec, _ = make_request_decoder(st)
        data = Vector{UInt8}(codeunits(raw_msg))
        idx = 1
        while idx <= length(data)
            chunk_size = rand(rng, 1:min(10, length(data) - idx + 1))
            status, consumed = AwsHTTP.h1_decode!(dec, @view data[idx:idx+chunk_size-1])
            @test status == AwsIO.OP_SUCCESS
            idx += chunk_size
        end
        @test st.done_count == 1
        AwsHTTP.h1_decoder_destroy!(dec)
    end
end

@testset "H1Decoder - encoding flags: gzip + chunked" begin
    flags_val = Ref(0)
    local the_dec
    vtable = AwsHTTP.H1DecoderVtable(
        _stub_on_header, _stub_on_body, _stub_on_request, _stub_on_response,
        (ud) -> (flags_val[] = AwsHTTP.h1_decoder_get_encoding_flags(the_dec); AwsIO.OP_SUCCESS))
    the_dec = AwsHTTP.h1_decoder_new(AwsHTTP.H1DecoderParams(1024, true, nothing, vtable))
    status, _ = AwsHTTP.h1_decode!(the_dec, "GET / HTTP/1.1\r\nTransfer-Encoding: gzip, chunked\r\n\r\n0\r\n\r\n")
    @test status == AwsIO.OP_SUCCESS
    @test flags_val[] == (AwsHTTP.HTTP_TRANSFER_ENCODING_GZIP | AwsHTTP.HTTP_TRANSFER_ENCODING_CHUNKED)
    AwsHTTP.h1_decoder_destroy!(the_dec)
end

@testset "H1Decoder - encoding flags: deflate + chunked" begin
    flags_val = Ref(0)
    local the_dec
    vtable = AwsHTTP.H1DecoderVtable(
        _stub_on_header, _stub_on_body, _stub_on_request, _stub_on_response,
        (ud) -> (flags_val[] = AwsHTTP.h1_decoder_get_encoding_flags(the_dec); AwsIO.OP_SUCCESS))
    the_dec = AwsHTTP.h1_decoder_new(AwsHTTP.H1DecoderParams(1024, true, nothing, vtable))
    status, _ = AwsHTTP.h1_decode!(the_dec, "GET / HTTP/1.1\r\nTransfer-Encoding: deflate, chunked\r\n\r\n0\r\n\r\n")
    @test status == AwsIO.OP_SUCCESS
    @test flags_val[] == (AwsHTTP.HTTP_TRANSFER_ENCODING_DEFLATE | AwsHTTP.HTTP_TRANSFER_ENCODING_CHUNKED)
    AwsHTTP.h1_decoder_destroy!(the_dec)
end

@testset "H1Decoder - encoding flags: x-compress + chunked" begin
    flags_val = Ref(0)
    local the_dec
    vtable = AwsHTTP.H1DecoderVtable(
        _stub_on_header, _stub_on_body, _stub_on_request, _stub_on_response,
        (ud) -> (flags_val[] = AwsHTTP.h1_decoder_get_encoding_flags(the_dec); AwsIO.OP_SUCCESS))
    the_dec = AwsHTTP.h1_decoder_new(AwsHTTP.H1DecoderParams(1024, true, nothing, vtable))
    status, _ = AwsHTTP.h1_decode!(the_dec, "GET / HTTP/1.1\r\nTransfer-Encoding: x-compress, chunked\r\n\r\n0\r\n\r\n")
    @test status == AwsIO.OP_SUCCESS
    @test flags_val[] == (AwsHTTP.HTTP_TRANSFER_ENCODING_DEPRECATED_COMPRESS | AwsHTTP.HTTP_TRANSFER_ENCODING_CHUNKED)
    AwsHTTP.h1_decoder_destroy!(the_dec)
end

@testset "H1Decoder - set_body_headers_ignored for HEAD" begin
    dec, st = make_response_decoder()
    AwsHTTP.h1_decoder_set_body_headers_ignored!(dec, true)
    msg = "HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\n"
    status, consumed = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test consumed == sizeof(msg)
    @test st.done_count == 1
    @test isempty(st.body_data)
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - query functions" begin
    dec, st = make_request_decoder()
    @test AwsHTTP.h1_decoder_get_encoding_flags(dec) == 0
    @test AwsHTTP.h1_decoder_get_content_length(dec) == 0
    @test AwsHTTP.h1_decoder_get_body_headers_ignored(dec) == false
    @test AwsHTTP.h1_decoder_get_header_block(dec) == AwsHTTP.HttpHeaderBlock.MAIN
    AwsHTTP.h1_decoder_set_logging_id!(dec, "test-id")
    @test dec.logging_id == "test-id"
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - extraneous data consumed" begin
    dec, st = make_request_decoder()
    msg = "GET / HTTP/1.1\r\nWow look here. That's a lot of extra random stuff!"
    status, consumed = AwsHTTP.h1_decode!(dec, msg)
    @test status == AwsIO.OP_SUCCESS
    @test consumed == sizeof(msg)
    @test st.done_count == 0
    AwsHTTP.h1_decoder_destroy!(dec)
end

@testset "H1Decoder - is_http_reason_phrase" begin
    @test AwsHTTP.is_http_reason_phrase("OK") == true
    @test AwsHTTP.is_http_reason_phrase("") == true
    @test AwsHTTP.is_http_reason_phrase("Not Found") == true
    @test AwsHTTP.is_http_reason_phrase("Not\tFound") == true
    @test AwsHTTP.is_http_reason_phrase(" Not Found ") == true
    @test AwsHTTP.is_http_reason_phrase("BAD\nPHRASE") == false
    @test AwsHTTP.is_http_reason_phrase("BAD\rPHRASE") == false
end

@testset "H1Decoder - bad requests" begin
    bad_requests = [
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n7\r\nMozilla\r\n2\r\nDeveloper\r\n7\r\nNetwork\r\n0\r\n\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked, gzip\r\n\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: gzip\r\n\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked, chunked\r\n\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked,\r\nTransfer-Encoding: chunked\r\n\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n7\r\nMozilla\r\nS\r\nDeveloper\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n 7 \r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n0x7\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: shrinkydinky, chunked\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: \r\nTransfer-Encoding: chunked\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: gzip, ,chunked\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: ,chunked\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked,\r\n",
        "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nFFFFFFFFFFFFFFFF1\r\n",
        "POST / HTTP/1.1\r\nContent-Length: 99999999999999999999\r\n",
        "POST / HTTP/1.1\r\nContent-Length:\r\n",
        "POST / HTTP/1.1\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n",
        "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nContent-Length: 0\r\n",
        "POST / HTTP/1.1\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n",
        "GET / HTTP/1.1\r\nHeader-Missing-Colon yes it is\r\n\r\n",
        "GET / HTTP/1.1\r\n: header with empty name\r\n\r\n",
        "POST / HTTP/1.1\r\nH@st: bad-char-in-name.com\r\n",
        "POST / HTTP/1.1\r\nHost : space-after-name.com\r\n",
        "POST / HTTP/1.1\r\n Host: space-before-name.com\r\n",
        "POST / HTTP/1.1\r\nHost: carriage-return\r.com\r\n",
        "POST / HTTP/1.1\r\nHost: \r\n obsolete-line-folding.com\r\n",
        "POST / HTTP/1.1\r\nHost: \r\n\tobsolete-line-folding.com\r\n",
        "POST / HTTP/1.1\r\nHost: amazon.com\r\nX-Fold: one\r\n next\r\n",
        " / HTTP/1.1\r\n",
        "GET  HTTP/1.1\r\n",
        "GET / \r\n",
        "GET /HTTP/1.1\r\n",
        "GET/HTTP/1.1\r\n",
        "GET / HTTP/1.1 \r\n",
        "G@T / HTTP/1.1\r\n",
    ]

    @testset "Entry $i" for (i, raw) in enumerate(bad_requests)
        dec, st = make_request_decoder()
        data = Vector{UInt8}(codeunits(raw))
        AwsIO.reset_error()
        status, _ = AwsHTTP.h1_decode!(dec, data)
        @test status == AwsIO.OP_ERR
        @test AwsIO.last_error() == AwsHTTP.ERROR_HTTP_PROTOCOL_ERROR
        AwsHTTP.h1_decoder_destroy!(dec)
    end
end

@testset "H1Decoder - bad responses" begin
    bad_responses = [
        "HTTP/1.1 1000 PHRASE\r\n",
        "HTTP/1.1 99 PHRASE\r\n",
        "HTTP/1.1 0x1 PHRASE\r\n",
        "HTTP/1.1 FFF PHRASE\r\n",
        "HTTP/1.1 200 BAD\nPHRASE\r\n",
    ]
    @testset "Response $i" for (i, raw) in enumerate(bad_responses)
        dec, st = make_response_decoder()
        data = Vector{UInt8}(codeunits(raw))
        AwsIO.reset_error()
        status, _ = AwsHTTP.h1_decode!(dec, data)
        @test status == AwsIO.OP_ERR
        AwsHTTP.h1_decoder_destroy!(dec)
    end
end

@testset "H1Decoder - auto-reset after complete message" begin
    dec, st = make_request_decoder()
    msg1 = "GET /first HTTP/1.1\r\n\r\n"
    msg2 = "POST /second HTTP/1.1\r\nContent-Length: 3\r\n\r\nabc"
    status1, _ = AwsHTTP.h1_decode!(dec, msg1)
    @test status1 == AwsIO.OP_SUCCESS
    @test st.done_count == 1
    @test st.requests[1][3] == "/first"

    status2, _ = AwsHTTP.h1_decode!(dec, msg2)
    @test status2 == AwsIO.OP_SUCCESS
    @test st.done_count == 2
    @test st.requests[2][3] == "/second"
    @test String(st.body_data) == "abc"
    AwsHTTP.h1_decoder_destroy!(dec)
end

# ═══════════════════════════════════════════════════════════════════════
# Phase 4/5: HTTP/1.1 Connection + Stream Tests
# ═══════════════════════════════════════════════════════════════════════

# Helper: track stream callbacks
mutable struct StreamCallbackState
    response_status::Int
    headers::Vector{Tuple{String,String}}
    header_block_done_count::Int
    body_data::Vector{UInt8}
    complete_error_code::Int
    complete_count::Int
    destroy_count::Int
end
StreamCallbackState() = StreamCallbackState(0, Tuple{String,String}[], 0, UInt8[], -1, 0, 0)

function _test_on_response_headers(stream, block, headers, ud)
    st = ud::StreamCallbackState
    for h in headers
        push!(st.headers, (h.name, h.value))
    end
    return AwsIO.OP_SUCCESS
end

function _test_on_response_header_block_done(stream, block, ud)
    st = ud::StreamCallbackState
    st.header_block_done_count += 1
    return AwsIO.OP_SUCCESS
end

function _test_on_response_body(stream, data, ud)
    st = ud::StreamCallbackState
    append!(st.body_data, data)
    return AwsIO.OP_SUCCESS
end

function _test_on_stream_complete(stream, error_code, ud)
    st = ud::StreamCallbackState
    st.complete_error_code = error_code
    st.complete_count += 1
    st.response_status = AwsHTTP.http_stream_get_incoming_response_status(stream)
    return nothing
end

function _test_on_stream_destroy(ud)
    st = ud::StreamCallbackState
    st.destroy_count += 1
    return nothing
end

@testset "H1Connection - client construction" begin
    conn = AwsHTTP.h1_connection_new_client()
    @test AwsHTTP.http_connection_is_open(conn)
    @test AwsHTTP.http_connection_is_client(conn)
    @test AwsHTTP.http_connection_get_version(conn) == AwsHTTP.HttpVersion.HTTP_1_1
    @test AwsHTTP.http_connection_new_requests_allowed(conn)
    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - server construction" begin
    conn = AwsHTTP.h1_connection_new_server()
    @test AwsHTTP.http_connection_is_open(conn)
    @test !AwsHTTP.http_connection_is_client(conn)
    @test AwsHTTP.http_connection_get_version(conn) == AwsHTTP.HttpVersion.HTTP_1_1
    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - close and stop_new_requests" begin
    conn = AwsHTTP.h1_connection_new_client()
    @test AwsHTTP.http_connection_new_requests_allowed(conn)
    AwsHTTP.http_connection_stop_new_requests(conn)
    @test !AwsHTTP.http_connection_new_requests_allowed(conn)
    @test AwsHTTP.http_connection_is_open(conn)  # still open, just no new requests

    conn2 = AwsHTTP.h1_connection_new_client()
    AwsHTTP.http_connection_close(conn2)
    @test !AwsHTTP.http_connection_is_open(conn2)
    @test !AwsHTTP.http_connection_new_requests_allowed(conn2)
    AwsHTTP.h1_connection_destroy!(conn)
    AwsHTTP.h1_connection_destroy!(conn2)
end

@testset "H1Connection - make_request on closed connection fails" begin
    conn = AwsHTTP.h1_connection_new_client()
    AwsHTTP.http_connection_close(conn)

    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")
    opts = AwsHTTP.HttpMakeRequestOptions(request=req)
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    @test stream === nothing
    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - make_request on server connection fails" begin
    conn = AwsHTTP.h1_connection_new_server()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")
    opts = AwsHTTP.HttpMakeRequestOptions(request=req)
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    @test stream === nothing
    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Stream - create and activate client stream" begin
    conn = AwsHTTP.h1_connection_new_client()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/index.html")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))

    st = StreamCallbackState()
    opts = AwsHTTP.HttpMakeRequestOptions(
        request=req,
        user_data=st,
        on_response_headers=_test_on_response_headers,
        on_response_header_block_done=_test_on_response_header_block_done,
        on_response_body=_test_on_response_body,
        on_complete=_test_on_stream_complete,
        on_destroy=_test_on_stream_destroy,
    )
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    @test stream !== nothing
    @test stream.api_state == AwsHTTP.H1StreamApiState.INIT

    err = AwsHTTP.h1_stream_activate!(stream)
    @test err == AwsIO.OP_SUCCESS
    @test stream.api_state == AwsHTTP.H1StreamApiState.ACTIVE
    @test stream.id == UInt32(1)  # first client stream
    @test length(conn.stream_list) == 1
    @test conn.incoming_stream === stream

    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - encode outgoing GET request" begin
    conn = AwsHTTP.h1_connection_new_client()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "example.com"))

    st = StreamCallbackState()
    opts = AwsHTTP.HttpMakeRequestOptions(request=req, user_data=st,
        on_response_headers=_test_on_response_headers,
        on_response_header_block_done=_test_on_response_header_block_done,
        on_complete=_test_on_stream_complete,
    )
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    AwsHTTP.h1_stream_activate!(stream)

    status, encoded = AwsHTTP.h1_connection_encode_outgoing!(conn)
    @test status == AwsIO.OP_SUCCESS
    encoded_str = String(encoded)
    @test occursin("GET / HTTP/1.1\r\n", encoded_str)
    @test occursin("Host: example.com\r\n", encoded_str)
    @test endswith(encoded_str, "\r\n\r\n")

    # Outgoing should be done
    @test stream.is_outgoing_message_done

    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - full client request/response cycle" begin
    conn = AwsHTTP.h1_connection_new_client()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/hello")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Host", "test.com"))

    st = StreamCallbackState()
    opts = AwsHTTP.HttpMakeRequestOptions(request=req, user_data=st,
        on_response_headers=_test_on_response_headers,
        on_response_header_block_done=_test_on_response_header_block_done,
        on_response_body=_test_on_response_body,
        on_complete=_test_on_stream_complete,
    )
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    AwsHTTP.h1_stream_activate!(stream)

    # Encode the request
    status, encoded = AwsHTTP.h1_connection_encode_outgoing!(conn)
    @test status == AwsIO.OP_SUCCESS
    @test stream.is_outgoing_message_done

    # Feed a response back
    response = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
    err = AwsHTTP.h1_connection_process_read_data!(conn, response)
    @test err == AwsIO.OP_SUCCESS

    # Verify callbacks fired
    @test st.response_status == 200
    @test st.header_block_done_count == 1
    @test ("Content-Length", "5") in st.headers
    @test String(st.body_data) == "hello"
    @test st.complete_count == 1
    @test st.complete_error_code == 0

    # Stream should be fully complete and removed
    @test isempty(conn.stream_list)
    @test conn.incoming_stream === nothing

    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - response with no body (204)" begin
    conn = AwsHTTP.h1_connection_new_client()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "DELETE")
    AwsHTTP.http_message_set_request_path(req, "/item/1")

    st = StreamCallbackState()
    opts = AwsHTTP.HttpMakeRequestOptions(request=req, user_data=st,
        on_response_headers=_test_on_response_headers,
        on_response_header_block_done=_test_on_response_header_block_done,
        on_complete=_test_on_stream_complete,
    )
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    AwsHTTP.h1_stream_activate!(stream)
    AwsHTTP.h1_connection_encode_outgoing!(conn)

    err = AwsHTTP.h1_connection_process_read_data!(conn, "HTTP/1.1 204 No Content\r\n\r\n")
    @test err == AwsIO.OP_SUCCESS
    @test st.response_status == 204
    @test st.complete_count == 1
    @test st.header_block_done_count == 1
    @test isempty(st.body_data)

    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - Connection: close marks final stream" begin
    conn = AwsHTTP.h1_connection_new_client()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "GET")
    AwsHTTP.http_message_set_request_path(req, "/")

    st = StreamCallbackState()
    opts = AwsHTTP.HttpMakeRequestOptions(request=req, user_data=st,
        on_response_headers=_test_on_response_headers,
        on_response_header_block_done=_test_on_response_header_block_done,
        on_complete=_test_on_stream_complete,
    )
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    AwsHTTP.h1_stream_activate!(stream)
    AwsHTTP.h1_connection_encode_outgoing!(conn)

    err = AwsHTTP.h1_connection_process_read_data!(conn, "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nok")
    @test err == AwsIO.OP_SUCCESS
    @test st.complete_count == 1
    # Connection should be closed after final stream
    @test !AwsHTTP.http_connection_is_open(conn)
    @test !AwsHTTP.http_connection_new_requests_allowed(conn)

    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - stream ID management" begin
    conn = AwsHTTP.h1_connection_new_client()

    for expected_id in [1, 3, 5]
        req = AwsHTTP.http_message_new_request()
        AwsHTTP.http_message_set_request_method(req, "GET")
        AwsHTTP.http_message_set_request_path(req, "/")
        st = StreamCallbackState()
        opts = AwsHTTP.HttpMakeRequestOptions(request=req, user_data=st,
            on_response_headers=_test_on_response_headers,
            on_response_header_block_done=_test_on_response_header_block_done,
            on_complete=_test_on_stream_complete,
        )
        stream = AwsHTTP.http_connection_make_request(conn, opts)
        AwsHTTP.h1_stream_activate!(stream)
        @test stream.id == UInt32(expected_id)

        # Encode and complete the cycle
        AwsHTTP.h1_connection_encode_outgoing!(conn)
        AwsHTTP.h1_connection_process_read_data!(conn, "HTTP/1.1 200 OK\r\n\r\n")
    end

    @test isempty(conn.stream_list)
    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - POST with body" begin
    conn = AwsHTTP.h1_connection_new_client()
    req = AwsHTTP.http_message_new_request()
    AwsHTTP.http_message_set_request_method(req, "POST")
    AwsHTTP.http_message_set_request_path(req, "/submit")
    AwsHTTP.http_message_add_header(req, AwsHTTP.HttpHeader("Content-Length", "11"))

    # Set body stream (encoder uses Julia IO interface: readbytes!, eof)
    body_stream = IOBuffer("hello world")
    AwsHTTP.http_message_set_body_stream(req, body_stream)

    st = StreamCallbackState()
    opts = AwsHTTP.HttpMakeRequestOptions(request=req, user_data=st,
        on_response_headers=_test_on_response_headers,
        on_response_header_block_done=_test_on_response_header_block_done,
        on_response_body=_test_on_response_body,
        on_complete=_test_on_stream_complete,
    )
    stream = AwsHTTP.http_connection_make_request(conn, opts)
    AwsHTTP.h1_stream_activate!(stream)

    # Encode - may need multiple calls for header + body
    all_encoded = UInt8[]
    for _ in 1:10
        status, chunk = AwsHTTP.h1_connection_encode_outgoing!(conn)
        @test status == AwsIO.OP_SUCCESS
        append!(all_encoded, chunk)
        stream.is_outgoing_message_done && break
    end

    encoded_str = String(all_encoded)
    @test occursin("POST /submit HTTP/1.1\r\n", encoded_str)
    @test occursin("Content-Length: 11\r\n", encoded_str)
    @test endswith(encoded_str, "hello world")
    @test stream.is_outgoing_message_done

    # Response
    AwsHTTP.h1_connection_process_read_data!(conn, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
    @test st.response_status == 200
    @test String(st.body_data) == "ok"
    @test st.complete_count == 1

    AwsHTTP.h1_connection_destroy!(conn)
end

@testset "H1Connection - query functions" begin
    conn = AwsHTTP.h1_connection_new_client()
    @test AwsHTTP.http_connection_is_client(conn) == true
    @test AwsHTTP.http_connection_get_version(conn) == AwsHTTP.HttpVersion.HTTP_1_1
    @test AwsHTTP.http_connection_is_open(conn) == true
    @test AwsHTTP.http_connection_new_requests_allowed(conn) == true
    AwsHTTP.h1_connection_destroy!(conn)

    conn2 = AwsHTTP.h1_connection_new_server()
    @test AwsHTTP.http_connection_is_client(conn2) == false
    AwsHTTP.h1_connection_destroy!(conn2)
end

# ─── Phase 6: HPACK (HTTP/2 header compression) ───

# ── Huffman coding ──

@testset "Huffman - encode/decode roundtrip" begin
    for s in ["", "hello", "www.example.com", "no-cache", "custom-key", "custom-value"]
        data = Vector{UInt8}(codeunits(s))
        encoded = AwsHTTP.hpack_huffman_encode(data)
        status, decoded = AwsHTTP.hpack_huffman_decode(encoded)
        @test status == AwsIO.OP_SUCCESS
        @test decoded == data
    end
end

@testset "Huffman - RFC 7541 C.4.1 www.example.com" begin
    # From RFC 7541 §C.4.1: Huffman encoding of "www.example.com"
    expected = UInt8[0xf1, 0xe3, 0xc2, 0xe5, 0xf2, 0x3a, 0x6b, 0xa0, 0xab, 0x90, 0xf4, 0xff]
    data = Vector{UInt8}(codeunits("www.example.com"))
    encoded = AwsHTTP.hpack_huffman_encode(data)
    @test encoded == expected

    status, decoded = AwsHTTP.hpack_huffman_decode(expected)
    @test status == AwsIO.OP_SUCCESS
    @test String(decoded) == "www.example.com"
end

@testset "Huffman - encoded length" begin
    data = Vector{UInt8}(codeunits("www.example.com"))
    @test AwsHTTP.hpack_huffman_encoded_length(data) == 12
end

@testset "Huffman - all byte values roundtrip" begin
    data = UInt8.(0:255)
    encoded = AwsHTTP.hpack_huffman_encode(data)
    status, decoded = AwsHTTP.hpack_huffman_decode(encoded)
    @test status == AwsIO.OP_SUCCESS
    @test decoded == data
end

# ── Integer encoding/decoding ──

@testset "HPACK integer - encode RFC 7541 C.1.1 (10 in 5-bit)" begin
    result = AwsHTTP.hpack_encode_integer(UInt64(10), UInt8(0), UInt8(5))
    @test result == UInt8[10]
end

@testset "HPACK integer - encode RFC 7541 C.1.2 (1337 in 5-bit)" begin
    result = AwsHTTP.hpack_encode_integer(UInt64(1337), UInt8(0), UInt8(5))
    @test result == UInt8[31, 154, 10]
end

@testset "HPACK integer - encode 42 in 8-bit prefix" begin
    result = AwsHTTP.hpack_encode_integer(UInt64(42), UInt8(0), UInt8(8))
    @test result == UInt8[42]
end

@testset "HPACK integer - encode 63 in 6-bit prefix" begin
    result = AwsHTTP.hpack_encode_integer(UInt64(63), UInt8(0), UInt8(6))
    @test result == UInt8[63, 0]
end

@testset "HPACK integer - decode 5-bit prefix (10)" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    data = UInt8[10]
    pos = Ref(1)
    status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, UInt8(5))
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test value == 10
    @test pos[] == 2
end

@testset "HPACK integer - decode 6-bit prefix (63)" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    data = UInt8[63, 0]
    pos = Ref(1)
    status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, UInt8(6))
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test value == 63
end

@testset "HPACK integer - decode 8-bit prefix (42)" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    data = UInt8[42]
    pos = Ref(1)
    status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, UInt8(8))
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test value == 42
end

@testset "HPACK integer - decode 5-bit prefix (1337)" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    data = UInt8[31, 154, 10]
    pos = Ref(1)
    status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, UInt8(5))
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test value == 1337
end

@testset "HPACK integer - decode incomplete" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    data = UInt8[31, 0xff]  # prefix filled, continuation byte with high bit set
    pos = Ref(1)
    status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, UInt8(5))
    @test status == AwsIO.OP_SUCCESS
    @test complete == false
end

@testset "HPACK integer - decode overflow" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    # Prefix full + 10 continuation bytes all 0xff = overflow
    data = UInt8[31, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    pos = Ref(1)
    status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, UInt8(5))
    @test status != AwsIO.OP_SUCCESS
end

@testset "HPACK integer - decode few in a row" begin
    dec = AwsHTTP.HpackIntegerDecoder()
    data = UInt8[10, 42, 63, 0, 31, 154, 10, 10]
    expected = [(UInt8(5), UInt64(10)), (UInt8(8), UInt64(42)), (UInt8(6), UInt64(63)),
                (UInt8(5), UInt64(1337)), (UInt8(5), UInt64(10))]
    pos = Ref(1)
    for (prefix, exp_val) in expected
        AwsHTTP._hpack_integer_decoder_reset!(dec)
        status, value, complete = AwsHTTP.hpack_decode_integer!(dec, data, pos, prefix)
        @test status == AwsIO.OP_SUCCESS
        @test complete == true
        @test value == exp_val
    end
    @test pos[] == length(data) + 1
end

# ── String encoding/decoding ──

@testset "HPACK string - decode blank" begin
    dec = AwsHTTP.HpackStringDecoder()
    data = UInt8[0]  # length=0, no Huffman
    pos = Ref(1)
    status, output, complete = AwsHTTP.hpack_decode_string!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test isempty(output)
end

@testset "HPACK string - decode uncompressed" begin
    dec = AwsHTTP.HpackStringDecoder()
    data = UInt8[5, UInt8('h'), UInt8('e'), UInt8('l'), UInt8('l'), UInt8('o')]
    pos = Ref(1)
    status, output, complete = AwsHTTP.hpack_decode_string!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test String(output) == "hello"
end

@testset "HPACK string - decode Huffman (www.example.com)" begin
    dec = AwsHTTP.HpackStringDecoder()
    # 0x8c = 10001100: Huffman flag + length 12
    data = UInt8[0x8c, 0xf1, 0xe3, 0xc2, 0xe5, 0xf2, 0x3a, 0x6b, 0xa0, 0xab, 0x90, 0xf4, 0xff]
    pos = Ref(1)
    status, output, complete = AwsHTTP.hpack_decode_string!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test complete == true
    @test String(output) == "www.example.com"
end

@testset "HPACK string - decode too large" begin
    dec = AwsHTTP.HpackStringDecoder()
    data = UInt8[5, UInt8('h'), UInt8('e'), UInt8('l'), UInt8('l'), UInt8('o')]
    pos = Ref(1)
    status, output, complete = AwsHTTP.hpack_decode_string!(dec, data, pos; max_length=4)
    @test status != AwsIO.OP_SUCCESS
end

@testset "HPACK string - encode roundtrip" begin
    for s in ["", "hello", "www.example.com", "custom-key"]
        encoded = AwsHTTP.hpack_encode_string(s; huffman_mode=AwsHTTP.HpackHuffmanMode.NEVER)
        dec = AwsHTTP.HpackStringDecoder()
        pos = Ref(1)
        status, output, complete = AwsHTTP.hpack_decode_string!(dec, encoded, pos)
        @test status == AwsIO.OP_SUCCESS
        @test complete == true
        @test String(output) == s
    end
end

@testset "HPACK string - encode Huffman roundtrip" begin
    for s in ["", "hello", "www.example.com", ":method"]
        encoded = AwsHTTP.hpack_encode_string(s; huffman_mode=AwsHTTP.HpackHuffmanMode.ALWAYS)
        dec = AwsHTTP.HpackStringDecoder()
        pos = Ref(1)
        status, output, complete = AwsHTTP.hpack_decode_string!(dec, encoded, pos)
        @test status == AwsIO.OP_SUCCESS
        @test complete == true
        @test String(output) == s
    end
end

# ── Static table ──

@testset "HPACK static table - get" begin
    ctx = AwsHTTP.HpackContext()

    # Index 1: :authority (no value)
    h = AwsHTTP.hpack_get_header(ctx, 1)
    @test h !== nothing
    @test h[1] == ":authority"
    @test h[2] == ""

    # Index 5: :path /index.html
    h = AwsHTTP.hpack_get_header(ctx, 5)
    @test h !== nothing
    @test h[1] == ":path"
    @test h[2] == "/index.html"

    # Index 21: age (no value)
    h = AwsHTTP.hpack_get_header(ctx, 21)
    @test h !== nothing
    @test h[1] == "age"
    @test h[2] == ""

    # Out of range
    @test AwsHTTP.hpack_get_header(ctx, 0) === nothing
    @test AwsHTTP.hpack_get_header(ctx, 69) === nothing
end

@testset "HPACK static table - find" begin
    ctx = AwsHTTP.HpackContext()

    # Exact match: :method GET = index 2
    idx, has_val = AwsHTTP.hpack_find_index(ctx, ":method", "GET")
    @test idx == 2
    @test has_val == true

    # Name match only: :method TEAPOT -> index 2, no value match
    idx, has_val = AwsHTTP.hpack_find_index(ctx, ":method", "TEAPOT")
    @test idx == 2
    @test has_val == false

    # Exact match: :authority with empty value = index 1 (name-only)
    idx, has_val = AwsHTTP.hpack_find_index(ctx, ":authority", "amazon.com")
    @test idx == 1
    @test has_val == false

    # Not found
    idx, has_val = AwsHTTP.hpack_find_index(ctx, "garbage", "value")
    @test idx == 0
    @test has_val == false
end

# ── Dynamic table ──

@testset "HPACK dynamic table - insert and find" begin
    ctx = AwsHTTP.HpackContext()

    AwsHTTP.hpack_insert_header!(ctx, "herp", "derp")
    idx, has_val = AwsHTTP.hpack_find_index(ctx, "herp", "derp")
    @test idx == 62
    @test has_val == true

    # Name-only match
    idx, has_val = AwsHTTP.hpack_find_index(ctx, "herp", "other")
    @test idx == 62
    @test has_val == false

    # Insert another
    AwsHTTP.hpack_insert_header!(ctx, "fizz", "buzz")
    idx, has_val = AwsHTTP.hpack_find_index(ctx, "fizz", "buzz")
    @test idx == 62
    @test has_val == true

    # Old entry shifted
    idx, has_val = AwsHTTP.hpack_find_index(ctx, "herp", "derp")
    @test idx == 63
    @test has_val == true
end

@testset "HPACK dynamic table - get by index" begin
    ctx = AwsHTTP.HpackContext()

    AwsHTTP.hpack_insert_header!(ctx, ":status", "302")
    AwsHTTP.hpack_insert_header!(ctx, "a", "b")
    AwsHTTP.hpack_insert_header!(ctx, "fizz", "buzz")

    h = AwsHTTP.hpack_get_header(ctx, 62)
    @test h == ("fizz", "buzz")

    h = AwsHTTP.hpack_get_header(ctx, 63)
    @test h == ("a", "b")

    h = AwsHTTP.hpack_get_header(ctx, 64)
    @test h == (":status", "302")

    @test AwsHTTP.hpack_get_header(ctx, 65) === nothing
end

@testset "HPACK dynamic table - eviction on resize" begin
    ctx = AwsHTTP.HpackContext()

    AwsHTTP.hpack_insert_header!(ctx, "herp", "derp")
    AwsHTTP.hpack_insert_header!(ctx, "fizz", "buzz")

    # Resize to only fit one entry
    fizz_size = AwsHTTP.hpack_get_header_size("fizz", "buzz")
    AwsHTTP.hpack_resize_dynamic_table!(ctx, fizz_size)

    # fizz survives, herp evicted
    idx, has_val = AwsHTTP.hpack_find_index(ctx, "fizz", "buzz")
    @test idx == 62
    @test has_val == true

    idx, _ = AwsHTTP.hpack_find_index(ctx, "herp", "derp")
    @test idx == 0
end

@testset "HPACK dynamic table - oversized header" begin
    ctx = AwsHTTP.HpackContext()

    # Set small table
    AwsHTTP.hpack_resize_dynamic_table!(ctx, 32)

    AwsHTTP.hpack_insert_header!(ctx, "a", "b")  # 1 + 1 + 32 = 34 > 32
    # Entry too large: table cleared, entry not inserted
    @test AwsHTTP.hpack_get_dynamic_table_num_elements(ctx) == 0
end

@testset "HPACK dynamic table - empty value" begin
    ctx = AwsHTTP.HpackContext()

    AwsHTTP.hpack_insert_header!(ctx, ":status", "302")
    AwsHTTP.hpack_insert_header!(ctx, "c", "")
    AwsHTTP.hpack_insert_header!(ctx, "a", "b")

    h = AwsHTTP.hpack_get_header(ctx, 62)
    @test h == ("a", "b")
    h = AwsHTTP.hpack_get_header(ctx, 63)
    @test h == ("c", "")
    h = AwsHTTP.hpack_get_header(ctx, 64)
    @test h == (":status", "302")
end

# ── HPACK Decoder ──

@testset "HPACK decoder - indexed from static table" begin
    dec = AwsHTTP.hpack_decoder_init()
    # 0x82 = 10000010 → indexed, index 2 → :method GET
    data = UInt8[0x82]
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test result.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
    @test result.header_name == ":method"
    @test result.header_value == "GET"
end

@testset "HPACK decoder - literal with indexing" begin
    dec = AwsHTTP.hpack_decoder_init()
    # 0x40 = literal with incremental indexing, name index 0 (new name)
    # followed by name string and value string
    data = UInt8[
        0x40,              # literal with indexing, name_index=0
        0x01, UInt8('a'),  # name: "a" (length 1, no Huffman)
        0x01, UInt8('b'),  # value: "b" (length 1, no Huffman)
    ]
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test result.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
    @test result.header_name == "a"
    @test result.header_value == "b"

    # Should be in dynamic table now
    h = AwsHTTP.hpack_get_header(dec.context, 62)
    @test h == ("a", "b")
end

@testset "HPACK decoder - literal with indexed name" begin
    dec = AwsHTTP.hpack_decoder_init()
    # 0x48 = 01001000 = literal with indexing, name index 8 → :status
    # value: "302" (length 3)
    data = UInt8[
        0x48,                                    # literal with indexing, name_index=8
        0x03, UInt8('3'), UInt8('0'), UInt8('2'), # value: "302"
    ]
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test result.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
    @test result.header_name == ":status"
    @test result.header_value == "302"

    h = AwsHTTP.hpack_get_header(dec.context, 62)
    @test h == (":status", "302")
end

@testset "HPACK decoder - indexed from dynamic table" begin
    dec = AwsHTTP.hpack_decoder_init()

    # First: literal with indexing, :status 302
    data = UInt8[
        0x48, 0x03, UInt8('3'), UInt8('0'), UInt8('2'),  # :status 302
        0x40, 0x01, UInt8('a'), 0x01, UInt8('b'),        # a: b
        0xbf,  # indexed: index 63 → :status 302 (second in dynamic table)
    ]
    pos = Ref(1)

    # Decode first header
    status, r1 = AwsHTTP.hpack_decode!(dec, data, pos)
    @test r1.header_name == ":status"
    @test r1.header_value == "302"

    # Decode second header
    status, r2 = AwsHTTP.hpack_decode!(dec, data, pos)
    @test r2.header_name == "a"
    @test r2.header_value == "b"

    # Decode third (indexed from dynamic table)
    status, r3 = AwsHTTP.hpack_decode!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test r3.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
    @test r3.header_name == ":status"
    @test r3.header_value == "302"
end

@testset "HPACK decoder - dynamic table size update" begin
    dec = AwsHTTP.hpack_decoder_init()
    # 0x20 = 001|00000 → table size update, size 0
    data = UInt8[0x20]
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    @test status == AwsIO.OP_SUCCESS
    @test result.type == AwsHTTP.HpackDecodeType.DYNAMIC_TABLE_RESIZE
    @test result.dynamic_table_resize == 0
    @test AwsHTTP.hpack_get_dynamic_table_max_size(dec.context) == 0
end

@testset "HPACK decoder - name too large" begin
    dec = AwsHTTP.hpack_decoder_init()
    AwsHTTP.hpack_decoder_set_max_string_length!(dec, 3)
    # literal without indexing, name length 4 (exceeds max of 3)
    data = UInt8[0x00, 0x04, UInt8('n'), UInt8('a'), UInt8('m'), UInt8('e'), 0x01, UInt8('v')]
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    @test status != AwsIO.OP_SUCCESS
end

@testset "HPACK decoder - value too large" begin
    dec = AwsHTTP.hpack_decoder_init()
    AwsHTTP.hpack_decoder_set_max_string_length!(dec, 3)
    # literal without indexing, name "n" (len 1), value "valu" (len 4, exceeds max)
    data = UInt8[0x00, 0x01, UInt8('n'), 0x04, UInt8('v'), UInt8('a'), UInt8('l'), UInt8('u')]
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    # First call may succeed (decodes name), but value decode should fail
    if status == AwsIO.OP_SUCCESS && result.type == AwsHTTP.HpackDecodeType.ONGOING
        status, result = AwsHTTP.hpack_decode!(dec, data, pos)
    end
    @test status != AwsIO.OP_SUCCESS
end

@testset "HPACK decoder - one byte at a time" begin
    dec = AwsHTTP.hpack_decoder_init()
    # Literal with indexing: name_index=8 (:status), value="302"
    full_data = UInt8[0x48, 0x03, UInt8('3'), UInt8('0'), UInt8('2')]

    result = AwsHTTP.HpackDecodeResult()
    global_pos = 1
    while global_pos <= length(full_data)
        chunk = UInt8[full_data[global_pos]]
        pos = Ref(1)
        status, result = AwsHTTP.hpack_decode!(dec, chunk, pos)
        @test status == AwsIO.OP_SUCCESS
        global_pos += pos[] - 1
        result.type != AwsHTTP.HpackDecodeType.ONGOING && break
    end
    @test result.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
    @test result.header_name == ":status"
    @test result.header_value == "302"
end

# ── HPACK Encoder ──

@testset "HPACK encoder - encode :method GET (indexed)" begin
    enc = AwsHTTP.hpack_encoder_init()
    AwsHTTP.hpack_encoder_set_huffman_mode!(enc, AwsHTTP.HpackHuffmanMode.NEVER)

    hdrs = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":method", "GET"))

    status, encoded = AwsHTTP.hpack_encode_header_block(enc, hdrs)
    @test status == AwsIO.OP_SUCCESS
    @test encoded == UInt8[0x82]  # indexed, index 2
end

@testset "HPACK encoder - encode literal with indexing" begin
    enc = AwsHTTP.hpack_encoder_init()
    AwsHTTP.hpack_encoder_set_huffman_mode!(enc, AwsHTTP.HpackHuffmanMode.NEVER)

    hdrs = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader("custom-key", "custom-value",
                                                              AwsHTTP.HttpHeaderCompression.USE_CACHE))

    status, encoded = AwsHTTP.hpack_encode_header_block(enc, hdrs)
    @test status == AwsIO.OP_SUCCESS

    # Decode it back
    dec = AwsHTTP.hpack_decoder_init()
    pos = Ref(1)
    status, result = AwsHTTP.hpack_decode!(dec, encoded, pos)
    @test status == AwsIO.OP_SUCCESS
    @test result.header_name == "custom-key"
    @test result.header_value == "custom-value"
end

@testset "HPACK encoder - size update from settings" begin
    enc = AwsHTTP.hpack_encoder_init()
    AwsHTTP.hpack_encoder_set_huffman_mode!(enc, AwsHTTP.HpackHuffmanMode.NEVER)

    AwsHTTP.hpack_encoder_update_max_table_size!(enc, UInt32(0))
    AwsHTTP.hpack_encoder_update_max_table_size!(enc, UInt32(1337))

    hdrs = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":method", "GET"))

    status, encoded = AwsHTTP.hpack_encode_header_block(enc, hdrs)
    @test status == AwsIO.OP_SUCCESS

    # Should contain: size_update(0), size_update(1337), indexed(:method GET)
    @test encoded[1] == 0x20  # size update 0
    @test encoded[2:4] == UInt8[0x3f, 0x9a, 0x0a]  # size update 1337 (5-bit prefix)
    @test encoded[5] == 0x82  # indexed :method GET
end

@testset "HPACK encoder/decoder roundtrip" begin
    enc = AwsHTTP.hpack_encoder_init()
    AwsHTTP.hpack_encoder_set_huffman_mode!(enc, AwsHTTP.HpackHuffmanMode.NEVER)

    hdrs = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":method", "GET"))
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":path", "/"))
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":scheme", "https"))
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader("custom-key", "custom-value"))

    status, encoded = AwsHTTP.hpack_encode_header_block(enc, hdrs)
    @test status == AwsIO.OP_SUCCESS

    # Decode all headers
    dec = AwsHTTP.hpack_decoder_init()
    pos = Ref(1)
    decoded_headers = Tuple{String,String}[]
    while pos[] <= length(encoded)
        status, result = AwsHTTP.hpack_decode!(dec, encoded, pos)
        @test status == AwsIO.OP_SUCCESS
        if result.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
            push!(decoded_headers, (result.header_name, result.header_value))
        end
    end
    @test length(decoded_headers) == 4
    @test decoded_headers[1] == (":method", "GET")
    @test decoded_headers[2] == (":path", "/")
    @test decoded_headers[3] == (":scheme", "https")
    @test decoded_headers[4] == ("custom-key", "custom-value")
end

@testset "HPACK encoder/decoder roundtrip with Huffman" begin
    enc = AwsHTTP.hpack_encoder_init()
    AwsHTTP.hpack_encoder_set_huffman_mode!(enc, AwsHTTP.HpackHuffmanMode.ALWAYS)

    hdrs = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":method", "GET"))
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader(":path", "/index.html"))
    AwsHTTP.http_headers_add_header(hdrs, AwsHTTP.HttpHeader("host", "www.example.com",
                                                              AwsHTTP.HttpHeaderCompression.USE_CACHE))

    status, encoded = AwsHTTP.hpack_encode_header_block(enc, hdrs)
    @test status == AwsIO.OP_SUCCESS

    dec = AwsHTTP.hpack_decoder_init()
    pos = Ref(1)
    decoded = Tuple{String,String}[]
    while pos[] <= length(encoded)
        status, result = AwsHTTP.hpack_decode!(dec, encoded, pos)
        @test status == AwsIO.OP_SUCCESS
        if result.type == AwsHTTP.HpackDecodeType.HEADER_FIELD
            push!(decoded, (result.header_name, result.header_value))
        end
    end
    @test length(decoded) == 3
    @test decoded[1] == (":method", "GET")
    @test decoded[2] == (":path", "/index.html")
    @test decoded[3] == ("host", "www.example.com")
end

# ─── Phase 7: HTTP/2 Frames ───

@testset "H2 frame type enum and string conversion" begin
    @test AwsHTTP.H2FrameType.DATA == AwsHTTP.H2FrameType.T(0x00)
    @test AwsHTTP.H2FrameType.HEADERS == AwsHTTP.H2FrameType.T(0x01)
    @test AwsHTTP.H2FrameType.PRIORITY == AwsHTTP.H2FrameType.T(0x02)
    @test AwsHTTP.H2FrameType.RST_STREAM == AwsHTTP.H2FrameType.T(0x03)
    @test AwsHTTP.H2FrameType.SETTINGS == AwsHTTP.H2FrameType.T(0x04)
    @test AwsHTTP.H2FrameType.PUSH_PROMISE == AwsHTTP.H2FrameType.T(0x05)
    @test AwsHTTP.H2FrameType.PING == AwsHTTP.H2FrameType.T(0x06)
    @test AwsHTTP.H2FrameType.GOAWAY == AwsHTTP.H2FrameType.T(0x07)
    @test AwsHTTP.H2FrameType.WINDOW_UPDATE == AwsHTTP.H2FrameType.T(0x08)
    @test AwsHTTP.H2FrameType.CONTINUATION == AwsHTTP.H2FrameType.T(0x09)
    @test AwsHTTP.h2_frame_type_to_str(AwsHTTP.H2FrameType.DATA) == "DATA"
    @test AwsHTTP.h2_frame_type_to_str(AwsHTTP.H2FrameType.GOAWAY) == "GOAWAY"
    @test AwsHTTP.h2_frame_type_to_str(AwsHTTP.H2FrameType.UNKNOWN) == "UNKNOWN"
end

@testset "H2 frame flags constants" begin
    @test AwsHTTP.H2_FRAME_F_ACK == 0x01
    @test AwsHTTP.H2_FRAME_F_END_STREAM == 0x01
    @test AwsHTTP.H2_FRAME_F_END_HEADERS == 0x04
    @test AwsHTTP.H2_FRAME_F_PADDED == 0x08
    @test AwsHTTP.H2_FRAME_F_PRIORITY == 0x20
end

@testset "H2 frame constants" begin
    @test AwsHTTP.H2_PAYLOAD_MAX == 0x00FFFFFF
    @test AwsHTTP.H2_WINDOW_UPDATE_MAX == 0x7FFFFFFF
    @test AwsHTTP.H2_STREAM_ID_MAX == 0x7FFFFFFF
    @test AwsHTTP.H2_FRAME_PREFIX_SIZE == 9
    @test AwsHTTP.H2_INIT_WINDOW_SIZE == 65535
    @test AwsHTTP.H2_PING_DATA_SIZE == 8
    @test length(AwsHTTP.H2_CONNECTION_PREFACE_CLIENT) == 24
end

@testset "H2Err construction and checks" begin
    s = AwsHTTP.H2ERR_SUCCESS
    @test AwsHTTP.h2err_success(s)
    @test !AwsHTTP.h2err_failed(s)

    e1 = AwsHTTP.h2err_from_h2_code(AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR)
    @test AwsHTTP.h2err_failed(e1)
    @test e1.h2_code == AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR

    e2 = AwsHTTP.h2err_from_aws_code(AwsHTTP.ERROR_HTTP_PROTOCOL_ERROR)
    @test AwsHTTP.h2err_failed(e2)
    @test e2.h2_code == AwsHTTP.Http2ErrorCode.INTERNAL_ERROR
end

@testset "H2 validate stream ID" begin
    @test AwsHTTP.h2_validate_stream_id(UInt32(1)) == AwsIO.OP_SUCCESS
    @test AwsHTTP.h2_validate_stream_id(UInt32(0x7FFFFFFF)) == AwsIO.OP_SUCCESS
    @test AwsHTTP.h2_validate_stream_id(UInt32(0)) == AwsIO.OP_ERR
    @test AwsHTTP.h2_validate_stream_id(UInt32(0x80000000)) == AwsIO.OP_ERR
end

@testset "Http2SettingsId enum" begin
    @test UInt16(AwsHTTP.Http2SettingsId.HEADER_TABLE_SIZE) == 0x01
    @test UInt16(AwsHTTP.Http2SettingsId.ENABLE_PUSH) == 0x02
    @test UInt16(AwsHTTP.Http2SettingsId.MAX_CONCURRENT_STREAMS) == 0x03
    @test UInt16(AwsHTTP.Http2SettingsId.INITIAL_WINDOW_SIZE) == 0x04
    @test UInt16(AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE) == 0x05
    @test UInt16(AwsHTTP.Http2SettingsId.MAX_HEADER_LIST_SIZE) == 0x06
end

@testset "H2 settings bounds and initial values" begin
    # Initial values match RFC 7540 6.5.2
    @test AwsHTTP.H2_SETTINGS_INITIAL[AwsHTTP.Http2SettingsId.HEADER_TABLE_SIZE] == 4096
    @test AwsHTTP.H2_SETTINGS_INITIAL[AwsHTTP.Http2SettingsId.ENABLE_PUSH] == 1
    @test AwsHTTP.H2_SETTINGS_INITIAL[AwsHTTP.Http2SettingsId.INITIAL_WINDOW_SIZE] == 65535
    @test AwsHTTP.H2_SETTINGS_INITIAL[AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE] == 16384

    # Bounds: ENABLE_PUSH is 0..1
    bounds = AwsHTTP.H2_SETTINGS_BOUNDS[AwsHTTP.Http2SettingsId.ENABLE_PUSH]
    @test bounds == (UInt32(0), UInt32(1))

    # Bounds: MAX_FRAME_SIZE is 16384..H2_PAYLOAD_MAX
    bounds = AwsHTTP.H2_SETTINGS_BOUNDS[AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE]
    @test bounds[1] == UInt32(16384)
    @test bounds[2] == UInt32(AwsHTTP.H2_PAYLOAD_MAX)
end

@testset "H2 frame prefix encode/decode roundtrip" begin
    prefix = AwsHTTP._h2_encode_frame_prefix(UInt32(256), UInt8(AwsHTTP.H2FrameType.HEADERS),
        AwsHTTP.H2_FRAME_F_END_STREAM | AwsHTTP.H2_FRAME_F_END_HEADERS, UInt32(7))
    @test length(prefix) == 9
    decoded, next_pos = AwsHTTP._h2_decode_frame_prefix(prefix, 1)
    @test next_pos == 10
    @test decoded.payload_len == 256
    @test decoded.frame_type == AwsHTTP.H2FrameType.HEADERS
    @test decoded.flags == (AwsHTTP.H2_FRAME_F_END_STREAM | AwsHTTP.H2_FRAME_F_END_HEADERS)
    @test decoded.stream_id == 7
end

@testset "H2 priority encoding/decoding" begin
    p = AwsHTTP.Http2PrioritySettings(UInt32(0x01234567), true, UInt16(9))
    encoded = AwsHTTP._h2_encode_priority(p)
    @test length(encoded) == 5
    # Top bit should be set (exclusive=true)
    @test (encoded[1] & 0x80) != 0
    decoded, next_pos = AwsHTTP._h2_decode_priority(encoded, 1)
    @test next_pos == 6
    @test decoded.stream_dependency == 0x01234567
    @test decoded.stream_dependency_exclusive == true
    @test decoded.weight == 9
end

# ─── Encoder tests ───

@testset "H2 encoder - PRIORITY frame" begin
    priority = AwsHTTP.Http2PrioritySettings(UInt32(0x01234567), true, UInt16(9))
    status, encoded = AwsHTTP.h2_encode_priority_frame(UInt32(0x76543210), priority)
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x05,           # Length = 5
        0x02,                        # Type = PRIORITY
        0x00,                        # Flags = none
        0x76, 0x54, 0x32, 0x10,     # Stream ID
        0x81, 0x23, 0x45, 0x67,     # Exclusive + Dependency
        0x09,                        # Weight
    ]
    @test encoded == expected
end

@testset "H2 encoder - RST_STREAM frame" begin
    status, encoded = AwsHTTP.h2_encode_rst_stream(UInt32(0x76543210), UInt32(0xFEEDBEEF))
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x04,           # Length = 4
        0x03,                        # Type = RST_STREAM
        0x00,                        # Flags
        0x76, 0x54, 0x32, 0x10,     # Stream ID
        0xFE, 0xED, 0xBE, 0xEF,     # Error Code
    ]
    @test encoded == expected
end

@testset "H2 encoder - SETTINGS frame" begin
    settings = [
        AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.ENABLE_PUSH, UInt32(1)),
    ]
    status, encoded = AwsHTTP.h2_encode_settings(settings)
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x06,           # Length = 6
        0x04,                        # Type = SETTINGS
        0x00,                        # Flags
        0x00, 0x00, 0x00, 0x00,     # Stream ID = 0
        0x00, 0x02,                  # Setting ID = ENABLE_PUSH
        0x00, 0x00, 0x00, 0x01,     # Value = 1
    ]
    @test encoded == expected
end

@testset "H2 encoder - SETTINGS ACK" begin
    status, encoded = AwsHTTP.h2_encode_settings(AwsHTTP.Http2Setting[]; ack=true)
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x00,           # Length = 0
        0x04,                        # Type = SETTINGS
        0x01,                        # Flags = ACK
        0x00, 0x00, 0x00, 0x00,     # Stream ID = 0
    ]
    @test encoded == expected
end

@testset "H2 encoder - PING frame with ACK" begin
    opaque = UInt8[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
    status, encoded = AwsHTTP.h2_encode_ping(opaque; ack=true)
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x08,           # Length = 8
        0x06,                        # Type = PING
        0x01,                        # Flags = ACK
        0x00, 0x00, 0x00, 0x00,     # Stream ID = 0
        0x00, 0x01, 0x02, 0x03,     # Opaque data
        0x04, 0x05, 0x06, 0x07,
    ]
    @test encoded == expected
end

@testset "H2 encoder - GOAWAY frame" begin
    debug = Vector{UInt8}(codeunits("goodbye"))
    status, encoded = AwsHTTP.h2_encode_goaway(UInt32(0x77665544), UInt32(0xFFEEDDCC); debug_data=debug)
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x0F,           # Length = 15
        0x07,                        # Type = GOAWAY
        0x00,                        # Flags
        0x00, 0x00, 0x00, 0x00,     # Stream ID = 0
        0x77, 0x66, 0x55, 0x44,     # Last-Stream-ID
        0xFF, 0xEE, 0xDD, 0xCC,     # Error Code
        UInt8('g'), UInt8('o'), UInt8('o'), UInt8('d'), UInt8('b'), UInt8('y'), UInt8('e'),
    ]
    @test encoded == expected
end

@testset "H2 encoder - WINDOW_UPDATE frame" begin
    status, encoded = AwsHTTP.h2_encode_window_update(UInt32(0x76543210), UInt32(0x7FFFFFFF))
    @test status == AwsIO.OP_SUCCESS
    expected = UInt8[
        0x00, 0x00, 0x04,           # Length = 4
        0x08,                        # Type = WINDOW_UPDATE
        0x00,                        # Flags
        0x76, 0x54, 0x32, 0x10,     # Stream ID
        0x7F, 0xFF, 0xFF, 0xFF,     # Window increment (max)
    ]
    @test encoded == expected
end

@testset "H2 encoder - DATA frame" begin
    body = UInt8[0x48, 0x65, 0x6C, 0x6C, 0x6F]  # "Hello"
    status, encoded = AwsHTTP.h2_encode_data(UInt32(1), body; end_stream=true)
    @test status == AwsIO.OP_SUCCESS
    @test length(encoded) == 9 + 5
    # Check prefix
    @test encoded[1:3] == UInt8[0x00, 0x00, 0x05]  # Length = 5
    @test encoded[4] == 0x00  # Type = DATA
    @test encoded[5] == 0x01  # Flags = END_STREAM
    @test encoded[10:14] == body
end

@testset "H2 encoder - DATA frame with padding" begin
    body = UInt8[0x48, 0x65, 0x6C, 0x6C, 0x6F]  # "Hello"
    status, encoded = AwsHTTP.h2_encode_data(UInt32(0x76543210), body;
        end_stream=true, pad_length=0x02)
    @test status == AwsIO.OP_SUCCESS
    # Payload = 1(pad_len) + 5(body) + 2(padding) = 8
    expected = UInt8[
        0x00, 0x00, 0x08,           # Length = 8
        0x00,                        # Type = DATA
        0x09,                        # Flags = END_STREAM | PADDED
        0x76, 0x54, 0x32, 0x10,     # Stream ID
        0x02,                        # Pad length
        0x48, 0x65, 0x6C, 0x6C, 0x6F,  # Body
        0x00, 0x00,                  # Padding
    ]
    @test encoded == expected
end

@testset "H2 encoder - HEADERS frame (simple)" begin
    enc = AwsHTTP.h2_frame_encoder_new()
    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, ":method", "GET")
    AwsHTTP.http_headers_add(headers, ":path", "/")

    status, encoded = AwsHTTP.h2_encode_headers(enc, UInt32(1), headers; end_stream=true)
    @test status == AwsIO.OP_SUCCESS
    @test length(encoded) > 9  # prefix + at least some header bytes
    # Check frame type
    @test encoded[4] == UInt8(AwsHTTP.H2FrameType.HEADERS)
    # Should have END_STREAM and END_HEADERS flags
    @test (encoded[5] & AwsHTTP.H2_FRAME_F_END_STREAM) != 0
    @test (encoded[5] & AwsHTTP.H2_FRAME_F_END_HEADERS) != 0
end

@testset "H2 encoder - RST_STREAM fails with stream_id=0" begin
    status, _ = AwsHTTP.h2_encode_rst_stream(UInt32(0), UInt32(1))
    @test status == AwsIO.OP_ERR
end

@testset "H2 encoder - WINDOW_UPDATE fails with oversized increment" begin
    status, _ = AwsHTTP.h2_encode_window_update(UInt32(1), UInt32(0x80000000))
    @test status == AwsIO.OP_ERR
end

# ─── Decoder tests ───

@testset "H2 decoder - construction" begin
    dec = AwsHTTP.h2_decoder_new(is_server=true)
    @test dec.is_server == true
    @test dec.max_frame_size == 16384
    @test dec.connection_preface_complete == false
end

@testset "H2 decoder - SETTINGS frame (client-side, no preface needed)" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    settings = [AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.ENABLE_PUSH, UInt32(0))]
    _, frame_data = AwsHTTP.h2_encode_settings(settings)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.SETTINGS
    @test !frame.ack
    @test length(frame.settings) == 1
    @test frame.settings[1].id == AwsHTTP.Http2SettingsId.ENABLE_PUSH
    @test frame.settings[1].value == 0
    @test pos == length(frame_data) + 1
end

@testset "H2 decoder - SETTINGS ACK" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    _, frame_data = AwsHTTP.h2_encode_settings(AwsHTTP.Http2Setting[]; ack=true)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.SETTINGS
    @test frame.ack
end

@testset "H2 decoder - PING roundtrip" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    opaque = UInt8[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
    _, frame_data = AwsHTTP.h2_encode_ping(opaque; ack=true)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.PING
    @test frame.ack
    @test frame.opaque_data == opaque
end

@testset "H2 decoder - RST_STREAM roundtrip" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    _, frame_data = AwsHTTP.h2_encode_rst_stream(UInt32(1), UInt32(0xFEEDBEEF))

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.RST_STREAM
    @test frame.stream_id == 1
    @test frame.error_code == 0xFEEDBEEF
end

@testset "H2 decoder - GOAWAY roundtrip" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    debug = Vector{UInt8}(codeunits("test"))
    _, frame_data = AwsHTTP.h2_encode_goaway(UInt32(3), UInt32(0x02); debug_data=debug)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.GOAWAY
    @test frame.last_stream_id == 3
    @test frame.goaway_error_code == 0x02
    @test frame.debug_data == debug
end

@testset "H2 decoder - WINDOW_UPDATE roundtrip" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    _, frame_data = AwsHTTP.h2_encode_window_update(UInt32(5), UInt32(32768))

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.WINDOW_UPDATE
    @test frame.stream_id == 5
    @test frame.window_increment == 32768
end

@testset "H2 decoder - PRIORITY roundtrip" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    priority = AwsHTTP.Http2PrioritySettings(UInt32(3), true, UInt16(255))
    _, frame_data = AwsHTTP.h2_encode_priority_frame(UInt32(7), priority)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.PRIORITY
    @test frame.stream_id == 7
    @test frame.priority !== nothing
    @test frame.priority.stream_dependency == 3
    @test frame.priority.stream_dependency_exclusive == true
    @test frame.priority.weight == 255
end

@testset "H2 decoder - DATA frame roundtrip" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    body = Vector{UInt8}(codeunits("Hello, HTTP/2!"))
    _, frame_data = AwsHTTP.h2_encode_data(UInt32(1), body; end_stream=true)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.DATA
    @test frame.stream_id == 1
    @test frame.end_stream == true
    @test frame.data == body
end

@testset "H2 decoder - DATA frame with padding" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    body = UInt8[0x48, 0x65, 0x6C, 0x6C, 0x6F]
    _, frame_data = AwsHTTP.h2_encode_data(UInt32(1), body; pad_length=0x03)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.DATA
    @test frame.data == body
end

@testset "H2 decoder - HEADERS roundtrip" begin
    enc = AwsHTTP.h2_frame_encoder_new()
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    headers = AwsHTTP.http_headers_new()
    AwsHTTP.http_headers_add(headers, ":method", "GET")
    AwsHTTP.http_headers_add(headers, ":path", "/")
    AwsHTTP.http_headers_add(headers, ":scheme", "https")
    AwsHTTP.http_headers_add(headers, ":authority", "example.com")

    status, frame_data = AwsHTTP.h2_encode_headers(enc, UInt32(1), headers; end_stream=true)
    @test status == AwsIO.OP_SUCCESS

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.HEADERS
    @test frame.stream_id == 1
    @test frame.end_stream == true
    @test length(frame.headers) == 4
    @test frame.headers[1].name == ":method"
    @test frame.headers[1].value == "GET"
    @test frame.headers[2].name == ":path"
    @test frame.headers[2].value == "/"
    @test frame.headers[3].name == ":scheme"
    @test frame.headers[3].value == "https"
    @test frame.headers[4].name == ":authority"
    @test frame.headers[4].value == "example.com"
end

@testset "H2 decoder - stream ID validation" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # SETTINGS with non-zero stream ID should fail
    bad_settings = AwsHTTP._h2_encode_frame_prefix(UInt32(0), UInt8(AwsHTTP.H2FrameType.SETTINGS), 0x00, UInt32(1))
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad_settings, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR
end

@testset "H2 decoder - SETTINGS invalid ACK with payload" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # ACK with non-zero payload length
    bad_ack = UInt8[
        0x00, 0x00, 0x06,  # Length = 6
        0x04,               # Type = SETTINGS
        0x01,               # Flags = ACK
        0x00, 0x00, 0x00, 0x00,  # Stream ID = 0
        0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  # bogus settings data
    ]
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad_ack, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.FRAME_SIZE_ERROR
end

@testset "H2 decoder - SETTINGS invalid payload length" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # Payload not multiple of 6
    bad = UInt8[
        0x00, 0x00, 0x05,  # Length = 5 (not % 6)
        0x04,               # Type = SETTINGS
        0x00,               # Flags
        0x00, 0x00, 0x00, 0x00,  # Stream ID = 0
        0x00, 0x01, 0x00, 0x00, 0x01,  # 5 bytes
    ]
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.FRAME_SIZE_ERROR
end

@testset "H2 decoder - SETTINGS invalid ENABLE_PUSH value" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    bad = UInt8[
        0x00, 0x00, 0x06,  # Length = 6
        0x04,               # Type = SETTINGS
        0x00,               # Flags
        0x00, 0x00, 0x00, 0x00,  # Stream ID = 0
        0x00, 0x02,              # ENABLE_PUSH
        0x00, 0x00, 0x00, 0x02,  # Value = 2 (invalid, must be 0 or 1)
    ]
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR
end

@testset "H2 decoder - SETTINGS INITIAL_WINDOW_SIZE out of bounds" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    bad = UInt8[
        0x00, 0x00, 0x06,  # Length = 6
        0x04,               # Type = SETTINGS
        0x00,               # Flags
        0x00, 0x00, 0x00, 0x00,  # Stream ID = 0
        0x00, 0x04,              # INITIAL_WINDOW_SIZE
        0x80, 0x00, 0x00, 0x00,  # Value = 2^31 (exceeds max)
    ]
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.FLOW_CONTROL_ERROR
end

@testset "H2 decoder - connection preface (server)" begin
    dec = AwsHTTP.h2_decoder_new(is_server=true)

    # Build: preface + SETTINGS frame
    settings = [AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.MAX_CONCURRENT_STREAMS, UInt32(100))]
    _, settings_frame = AwsHTTP.h2_encode_settings(settings)
    wire = vcat(Vector{UInt8}(AwsHTTP.H2_CONNECTION_PREFACE_CLIENT), settings_frame)

    err, frame, pos = AwsHTTP.h2_decode_frame(dec, wire, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.SETTINGS
    @test dec.connection_preface_complete == true
    @test length(frame.settings) == 1
    @test frame.settings[1].value == 100
end

@testset "H2 decoder - bad connection preface" begin
    dec = AwsHTTP.h2_decoder_new(is_server=true)

    # Bad preface
    bad = b"BAD PREFACE DATA THAT IS LONG ENOUGH TO PARSE"
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad, 1)
    @test AwsHTTP.h2err_failed(err)
end

@testset "H2 decoder - multiple frames sequential" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # Concatenate several frames
    _, f1 = AwsHTTP.h2_encode_window_update(UInt32(0), UInt32(1000))
    _, f2 = AwsHTTP.h2_encode_ping(UInt8[1,2,3,4,5,6,7,8])
    _, f3 = AwsHTTP.h2_encode_window_update(UInt32(1), UInt32(500))
    wire = vcat(f1, f2, f3)

    err1, frame1, pos1 = AwsHTTP.h2_decode_frame(dec, wire, 1)
    @test AwsHTTP.h2err_success(err1)
    @test frame1.frame_type == AwsHTTP.H2FrameType.WINDOW_UPDATE
    @test frame1.window_increment == 1000

    err2, frame2, pos2 = AwsHTTP.h2_decode_frame(dec, wire, pos1)
    @test AwsHTTP.h2err_success(err2)
    @test frame2.frame_type == AwsHTTP.H2FrameType.PING

    err3, frame3, pos3 = AwsHTTP.h2_decode_frame(dec, wire, pos2)
    @test AwsHTTP.h2err_success(err3)
    @test frame3.frame_type == AwsHTTP.H2FrameType.WINDOW_UPDATE
    @test frame3.window_increment == 500
    @test pos3 == length(wire) + 1
end

@testset "H2 decoder - incomplete data returns UNKNOWN (need more)" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # Only 5 bytes, need at least 9 for prefix
    partial = UInt8[0x00, 0x00, 0x04, 0x08, 0x00]
    err, frame, pos = AwsHTTP.h2_decode_frame(dec, partial, 1)
    @test AwsHTTP.h2err_success(err)
    @test frame.frame_type == AwsHTTP.H2FrameType.UNKNOWN
    @test pos == 1  # pos unchanged
end

@testset "H2 decoder - CONTINUATION without HEADERS fails" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # CONTINUATION frame with no preceding HEADERS
    cont = AwsHTTP._h2_encode_frame_prefix(UInt32(0), UInt8(AwsHTTP.H2FrameType.CONTINUATION),
        AwsHTTP.H2_FRAME_F_END_HEADERS, UInt32(1))
    err, _, _ = AwsHTTP.h2_decode_frame(dec, cont, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR
end

@testset "H2 decoder - RST_STREAM wrong payload size" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true

    # RST_STREAM with 3 bytes payload (should be 4)
    bad = UInt8[
        0x00, 0x00, 0x03,       # Length = 3
        0x03,                    # RST_STREAM
        0x00,
        0x00, 0x00, 0x00, 0x01, # Stream ID = 1
        0xFE, 0xED, 0xBE,       # Only 3 bytes
    ]
    err, _, _ = AwsHTTP.h2_decode_frame(dec, bad, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.FRAME_SIZE_ERROR
end

@testset "H2 settings header encode/decode roundtrip" begin
    settings = [
        AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.ENABLE_PUSH, UInt32(0)),
        AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE, UInt32(65536)),
    ]
    status, encoded = AwsHTTP.h2_encode_http2_settings_header(settings)
    @test status == AwsIO.OP_SUCCESS
    @test !isempty(encoded)

    status2, decoded = AwsHTTP.h2_decode_http2_settings_header(encoded)
    @test status2 == AwsIO.OP_SUCCESS
    @test length(decoded) == 2
    @test decoded[1].id == AwsHTTP.Http2SettingsId.ENABLE_PUSH
    @test decoded[1].value == 0
    @test decoded[2].id == AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE
    @test decoded[2].value == 65536
end

@testset "H2 settings header invalid base64" begin
    status, _ = AwsHTTP.h2_decode_http2_settings_header(Vector{UInt8}(codeunits("\$\$\$")))
    @test status == AwsIO.OP_ERR
end

@testset "H2 settings header invalid length" begin
    # 5 bytes is not a multiple of 6
    bad_b64 = AwsHTTP.base64url_encode(UInt8[0x00, 0x01, 0x00, 0x00, 0x01])
    status, _ = AwsHTTP.h2_decode_http2_settings_header(bad_b64)
    @test status == AwsIO.OP_ERR
end

@testset "H2 settings header invalid value" begin
    # ENABLE_PUSH (0x02) with value 2 (invalid)
    binary = UInt8[0x00, 0x02, 0x00, 0x00, 0x00, 0x02]
    b64 = AwsHTTP.base64url_encode(binary)
    status, _ = AwsHTTP.h2_decode_http2_settings_header(b64)
    @test status == AwsIO.OP_ERR
end

@testset "H2 decoder - frame exceeds max_frame_size" begin
    dec = AwsHTTP.h2_decoder_new(is_server=false)
    dec.connection_preface_complete = true
    dec.max_frame_size = UInt32(10)  # Tiny max

    # Frame with 11 bytes payload
    frame_data = vcat(
        AwsHTTP._h2_encode_frame_prefix(UInt32(11), UInt8(AwsHTTP.H2FrameType.DATA),
            0x00, UInt32(1)),
        zeros(UInt8, 11))

    err, _, _ = AwsHTTP.h2_decode_frame(dec, frame_data, 1)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.FRAME_SIZE_ERROR
end

# ─── Phase 8: HTTP/2 Connection ───

@testset "H2 connection - client construction" begin
    conn = AwsHTTP.h2_connection_new(is_client=true)
    @test conn.is_client == true
    @test conn.http_version == AwsHTTP.HttpVersion.HTTP_2
    @test conn.next_stream_id == UInt32(1)
    @test conn.is_open == true
    @test conn.new_requests_allowed == true
    @test !conn.goaway_sent
    @test !conn.goaway_received
    @test AwsHTTP.http_connection_is_client(conn)
    @test AwsHTTP.http_connection_is_open(conn)
    @test AwsHTTP.http_connection_get_version(conn) == AwsHTTP.HttpVersion.HTTP_2
end

@testset "H2 connection - server construction" begin
    conn = AwsHTTP.h2_connection_new(is_client=false)
    @test conn.is_client == false
    @test conn.next_stream_id == UInt32(2)
end

@testset "H2 connection - close and stop_new_requests" begin
    conn = AwsHTTP.h2_connection_new()
    @test AwsHTTP.http_connection_new_requests_allowed(conn)

    AwsHTTP.http_connection_stop_new_requests(conn)
    @test !AwsHTTP.http_connection_new_requests_allowed(conn)
    @test AwsHTTP.http_connection_is_open(conn)  # still open

    AwsHTTP.http_connection_close(conn)
    @test !AwsHTTP.http_connection_is_open(conn)
end

@testset "H2 connection - client preface" begin
    conn = AwsHTTP.h2_connection_new(is_client=true)
    status, preface = AwsHTTP.h2_connection_get_preface(conn)
    @test status == AwsIO.OP_SUCCESS
    @test !isempty(preface)
    # Should start with client magic string
    @test preface[1:24] == Vector{UInt8}(AwsHTTP.H2_CONNECTION_PREFACE_CLIENT)
    # Followed by SETTINGS frame (type byte at offset 24+4 should be 0x04)
    @test preface[28] == UInt8(AwsHTTP.H2FrameType.SETTINGS)
    @test conn.connection_preface_sent
end

@testset "H2 connection - server preface" begin
    conn = AwsHTTP.h2_connection_new(is_client=false)
    status, preface = AwsHTTP.h2_connection_get_preface(conn)
    @test status == AwsIO.OP_SUCCESS
    # Server preface starts with SETTINGS directly (no magic string)
    @test preface[4] == UInt8(AwsHTTP.H2FrameType.SETTINGS)
end

@testset "H2 connection - settings initial values" begin
    conn = AwsHTTP.h2_connection_new()
    local_settings = AwsHTTP.h2_connection_get_local_settings(conn)
    @test local_settings[AwsHTTP.Http2SettingsId.HEADER_TABLE_SIZE] == 4096
    @test local_settings[AwsHTTP.Http2SettingsId.ENABLE_PUSH] == 1
    @test local_settings[AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE] == 16384
    @test local_settings[AwsHTTP.Http2SettingsId.INITIAL_WINDOW_SIZE] == 65535
end

@testset "H2 connection - change settings" begin
    conn = AwsHTTP.h2_connection_new()
    completed = Ref(false)
    cb = (err, ud) -> begin completed[] = true end

    settings = [AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.MAX_CONCURRENT_STREAMS, UInt32(100))]
    status = AwsHTTP.h2_connection_change_settings!(conn, settings; on_completed=cb)
    @test status == AwsIO.OP_SUCCESS
    @test length(conn.pending_settings_queue) == 1
    @test !isempty(conn.outgoing_frames)

    # Simulate receiving ACK
    err = AwsHTTP.h2_connection_on_settings_ack!(conn)
    @test AwsHTTP.h2err_success(err)
    @test isempty(conn.pending_settings_queue)
    @test completed[]
    @test conn.settings_local[AwsHTTP.Http2SettingsId.MAX_CONCURRENT_STREAMS] == 100
end

@testset "H2 connection - settings ACK without pending fails" begin
    conn = AwsHTTP.h2_connection_new()
    err = AwsHTTP.h2_connection_on_settings_ack!(conn)
    @test AwsHTTP.h2err_failed(err)
    @test err.h2_code == AwsHTTP.Http2ErrorCode.PROTOCOL_ERROR
end

@testset "H2 connection - receive remote settings" begin
    conn = AwsHTTP.h2_connection_new()
    changed_ref = Ref{Vector{AwsHTTP.Http2Setting}}(AwsHTTP.Http2Setting[])
    conn.on_remote_settings_change = (s) -> begin changed_ref[] = s end

    settings = [AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE, UInt32(32768))]
    err = AwsHTTP.h2_connection_on_settings_received!(conn, settings)
    @test AwsHTTP.h2err_success(err)
    @test conn.settings_remote[AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE] == 32768
    # Should have queued SETTINGS ACK
    @test !isempty(conn.outgoing_high_priority)
    # Callback should have been invoked
    @test length(changed_ref[]) == 1
end

@testset "H2 connection - GOAWAY send and receive" begin
    conn = AwsHTTP.h2_connection_new()
    goaway_ref = Ref{Tuple{UInt32, UInt32}}((UInt32(0), UInt32(0)))
    conn.on_goaway_received = (last_id, err_code, debug) -> begin goaway_ref[] = (last_id, err_code) end

    # Send GOAWAY
    status = AwsHTTP.h2_connection_send_goaway!(conn; error_code=UInt32(0))
    @test status == AwsIO.OP_SUCCESS
    @test conn.goaway_sent
    @test !isempty(conn.outgoing_high_priority)

    sent, last_id, err_code = AwsHTTP.h2_connection_get_sent_goaway(conn)
    @test sent
    @test err_code == 0

    # Receive GOAWAY
    err = AwsHTTP.h2_connection_on_goaway_received!(conn, UInt32(5), UInt32(0x02), UInt8[])
    @test AwsHTTP.h2err_success(err)
    @test conn.goaway_received
    @test !conn.new_requests_allowed
    @test goaway_ref[] == (UInt32(5), UInt32(0x02))

    recv, last_id2, err_code2 = AwsHTTP.h2_connection_get_received_goaway(conn)
    @test recv
    @test last_id2 == 5
    @test err_code2 == 0x02
end

@testset "H2 connection - GOAWAY last_stream_id must not increase" begin
    conn = AwsHTTP.h2_connection_new()

    err1 = AwsHTTP.h2_connection_on_goaway_received!(conn, UInt32(10), UInt32(0), UInt8[])
    @test AwsHTTP.h2err_success(err1)

    # Second GOAWAY with higher last_stream_id should fail
    err2 = AwsHTTP.h2_connection_on_goaway_received!(conn, UInt32(20), UInt32(0), UInt8[])
    @test AwsHTTP.h2err_failed(err2)

    # Lower is fine
    err3 = AwsHTTP.h2_connection_on_goaway_received!(conn, UInt32(5), UInt32(0), UInt8[])
    @test AwsHTTP.h2err_success(err3)
end

@testset "H2 connection - PING send and ACK" begin
    conn = AwsHTTP.h2_connection_new()
    rtt_ref = Ref{UInt64}(UInt64(0))
    cb = (rtt, err, ud) -> begin rtt_ref[] = rtt end

    opaque = UInt8[1,2,3,4,5,6,7,8]
    status = AwsHTTP.h2_connection_send_ping!(conn, opaque; on_completed=cb)
    @test status == AwsIO.OP_SUCCESS
    @test length(conn.pending_pings) == 1

    # Simulate receiving ACK
    err = AwsHTTP.h2_connection_on_ping_ack!(conn, opaque)
    @test AwsHTTP.h2err_success(err)
    @test isempty(conn.pending_pings)
    @test rtt_ref[] > 0  # should have some RTT
end

@testset "H2 connection - PING ACK without pending fails" begin
    conn = AwsHTTP.h2_connection_new()
    err = AwsHTTP.h2_connection_on_ping_ack!(conn, zeros(UInt8, 8))
    @test AwsHTTP.h2err_failed(err)
end

@testset "H2 connection - PING ACK mismatch fails" begin
    conn = AwsHTTP.h2_connection_new()
    AwsHTTP.h2_connection_send_ping!(conn, UInt8[1,2,3,4,5,6,7,8])
    err = AwsHTTP.h2_connection_on_ping_ack!(conn, UInt8[8,7,6,5,4,3,2,1])
    @test AwsHTTP.h2err_failed(err)
end

@testset "H2 connection - receive PING sends ACK" begin
    conn = AwsHTTP.h2_connection_new()
    err = AwsHTTP.h2_connection_on_ping!(conn, UInt8[1,2,3,4,5,6,7,8])
    @test AwsHTTP.h2err_success(err)
    @test !isempty(conn.outgoing_high_priority)
end

@testset "H2 connection - flow control window update" begin
    conn = AwsHTTP.h2_connection_new()
    old_window = conn.window_size_self

    status = AwsHTTP.h2_connection_update_window!(conn, UInt32(1000))
    @test status == AwsIO.OP_SUCCESS
    @test conn.window_size_self == old_window + 1000
    @test !isempty(conn.outgoing_frames)
end

@testset "H2 connection - window update overflow protection" begin
    conn = AwsHTTP.h2_connection_new()
    conn.window_size_self = Int64(AwsHTTP.H2_WINDOW_UPDATE_MAX) - 100
    # Trying to add 200 would overflow
    status = AwsHTTP.h2_connection_update_window!(conn, UInt32(200))
    @test status == AwsIO.OP_ERR
end

@testset "H2 connection - decode dispatches SETTINGS" begin
    # Client connection
    conn = AwsHTTP.h2_connection_new(is_client=true)
    conn.decoder.connection_preface_complete = true

    # Encode a SETTINGS frame with MAX_FRAME_SIZE=32768
    settings = [AwsHTTP.Http2Setting(AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE, UInt32(32768))]
    _, frame_data = AwsHTTP.h2_encode_settings(settings)

    err, stream_frames = AwsHTTP.h2_connection_decode!(conn, frame_data)
    @test AwsHTTP.h2err_success(err)
    @test isempty(stream_frames)  # SETTINGS is connection-level
    @test conn.settings_remote[AwsHTTP.Http2SettingsId.MAX_FRAME_SIZE] == 32768
    # Should have queued SETTINGS ACK
    @test !isempty(conn.outgoing_high_priority)
end

@testset "H2 connection - decode dispatches PING" begin
    conn = AwsHTTP.h2_connection_new(is_client=true)
    conn.decoder.connection_preface_complete = true

    opaque = UInt8[0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE]
    _, frame_data = AwsHTTP.h2_encode_ping(opaque)

    err, stream_frames = AwsHTTP.h2_connection_decode!(conn, frame_data)
    @test AwsHTTP.h2err_success(err)
    @test isempty(stream_frames)
    # Should have queued PING ACK
    @test !isempty(conn.outgoing_high_priority)
end

@testset "H2 connection - decode dispatches GOAWAY" begin
    conn = AwsHTTP.h2_connection_new(is_client=true)
    conn.decoder.connection_preface_complete = true

    _, frame_data = AwsHTTP.h2_encode_goaway(UInt32(7), UInt32(0); debug_data=UInt8[])

    err, stream_frames = AwsHTTP.h2_connection_decode!(conn, frame_data)
    @test AwsHTTP.h2err_success(err)
    @test conn.goaway_received
    @test conn.goaway_received_last_stream_id == 7
end

@testset "H2 connection - decode passes DATA to caller" begin
    conn = AwsHTTP.h2_connection_new(is_client=true)
    conn.decoder.connection_preface_complete = true

    _, frame_data = AwsHTTP.h2_encode_data(UInt32(1), UInt8[0x01, 0x02, 0x03]; end_stream=true)

    err, stream_frames = AwsHTTP.h2_connection_decode!(conn, frame_data)
    @test AwsHTTP.h2err_success(err)
    @test length(stream_frames) == 1
    @test stream_frames[1].frame_type == AwsHTTP.H2FrameType.DATA
    @test stream_frames[1].data == UInt8[0x01, 0x02, 0x03]
    @test stream_frames[1].end_stream == true
end

@testset "H2 connection - decode connection-level WINDOW_UPDATE" begin
    conn = AwsHTTP.h2_connection_new(is_client=true)
    conn.decoder.connection_preface_complete = true
    old_peer_window = conn.window_size_peer

    _, frame_data = AwsHTTP.h2_encode_window_update(UInt32(0), UInt32(5000))

    err, stream_frames = AwsHTTP.h2_connection_decode!(conn, frame_data)
    @test AwsHTTP.h2err_success(err)
    @test conn.window_size_peer == old_peer_window + 5000
end

@testset "H2 connection - get_outgoing_frames! priority ordering" begin
    conn = AwsHTTP.h2_connection_new()

    # Queue normal frame
    push!(conn.outgoing_frames, UInt8[0x01, 0x02])
    # Queue high-priority frame
    push!(conn.outgoing_high_priority, UInt8[0xAA, 0xBB])

    output = AwsHTTP.h2_connection_get_outgoing_frames!(conn)
    @test length(output) == 4
    # High priority should come first
    @test output[1:2] == UInt8[0xAA, 0xBB]
    @test output[3:4] == UInt8[0x01, 0x02]
    # Queues should be empty
    @test isempty(conn.outgoing_frames)
    @test isempty(conn.outgoing_high_priority)
end

@testset "H2 connection - full client/server preface exchange" begin
    client = AwsHTTP.h2_connection_new(is_client=true)
    server = AwsHTTP.h2_connection_new(is_client=false)

    # Client generates preface
    status_c, client_preface = AwsHTTP.h2_connection_get_preface(client)
    @test status_c == AwsIO.OP_SUCCESS

    # Server generates preface
    status_s, server_preface = AwsHTTP.h2_connection_get_preface(server)
    @test status_s == AwsIO.OP_SUCCESS

    # Server decodes client preface (includes magic + SETTINGS)
    err_s, frames_s = AwsHTTP.h2_connection_decode!(server, client_preface)
    @test AwsHTTP.h2err_success(err_s)
    @test server.decoder.connection_preface_complete

    # Client decodes server preface (SETTINGS)
    err_c, frames_c = AwsHTTP.h2_connection_decode!(client, server_preface)
    @test AwsHTTP.h2err_success(err_c)

    # Both should have queued SETTINGS ACK
    server_out = AwsHTTP.h2_connection_get_outgoing_frames!(server)
    client_out = AwsHTTP.h2_connection_get_outgoing_frames!(client)
    @test !isempty(server_out)
    @test !isempty(client_out)
end
