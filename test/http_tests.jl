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
