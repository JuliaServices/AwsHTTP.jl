module AwsHTTP

using AwsIO
using EnumX

# Re-export error infrastructure from AwsIO that we depend on
using AwsIO: ERROR_ENUM_BEGIN_RANGE, ERROR_ENUM_END_RANGE,
             LOG_SUBJECT_BEGIN_RANGE, LOG_SUBJECT_END_RANGE,
             LogSubject

# --- core ---
include("http.jl")

end # module AwsHTTP
