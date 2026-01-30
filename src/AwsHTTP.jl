module AwsHTTP

using AwsIO
using EnumX

# Re-export error infrastructure from AwsIO that we depend on
using AwsIO: ERROR_ENUM_BEGIN_RANGE, ERROR_ENUM_END_RANGE,
             LOG_SUBJECT_BEGIN_RANGE, LOG_SUBJECT_END_RANGE,
             LogSubject,
             OP_SUCCESS, OP_ERR, raise_error,
             ERROR_INVALID_INDEX, ERROR_INVALID_ARGUMENT,
             ERROR_INVALID_STATE, ERROR_UNIMPLEMENTED

# --- core ---
include("http.jl")

# --- request/response ---
include("request_response.jl")

# --- HTTP/1.1 encoder ---
include("h1_encoder.jl")

end # module AwsHTTP
