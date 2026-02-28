# HTTP Proxy support - Strategy pattern, negotiation, no-proxy matching
# Port of aws-c-http/proxy.h, proxy_connection.c, proxy_strategy.c, no_proxy.c

# ─── Proxy enums ───

@enumx HttpProxyConnectionType::UInt8 begin
    HTTP_LEGACY = 0
    HTTP_FORWARD = 1
    HTTP_TUNNEL = 2
end

@enumx HttpProxyAuthenticationType::UInt8 begin
    NONE = 0
    BASIC = 1
end

@enumx HttpProxyEnvVarType::UInt8 begin
    DISABLE = 0
    ENABLE = 1
end

@enumx HttpProxyNegotiationRetryDirective::UInt8 begin
    STOP = 0
    NEW_CONNECTION = 1
    CURRENT_CONNECTION = 2
end

# ─── Proxy negotiator vtables ───

struct HttpProxyNegotiatorForwardingVtable{FRT}
    forward_request_transform::FRT  # (negotiator, message) -> Int
end

struct HttpProxyNegotiatorTunnellingVtable{FCRT, FIH, FS, FIB, FRD}
    connect_request_transform::FCRT # (negotiator, message, on_done, on_forward, user_data) -> Nothing
    on_incoming_headers::FIH        # (negotiator, header_block, headers) -> Int
    on_status::FS                   # (negotiator, status_code) -> Int
    on_incoming_body::FIB           # (negotiator, data) -> Int
    get_retry_directive::FRD        # (negotiator) -> HttpProxyNegotiationRetryDirective.T
end

# ─── Proxy negotiator ───

mutable struct HttpProxyNegotiator{Impl, FV <: Union{HttpProxyNegotiatorForwardingVtable, Nothing}, TV <: Union{HttpProxyNegotiatorTunnellingVtable, Nothing}}
    impl::Impl
    is_tunnelling::Bool
    forwarding_vtable::FV
    tunnelling_vtable::TV
end

function http_proxy_negotiator_get_retry_directive(n::HttpProxyNegotiator)::HttpProxyNegotiationRetryDirective.T
    if n.is_tunnelling && n.tunnelling_vtable !== nothing && n.tunnelling_vtable.get_retry_directive !== nothing
        return n.tunnelling_vtable.get_retry_directive(n)
    end
    return HttpProxyNegotiationRetryDirective.STOP
end

# ─── Proxy strategy ───

struct HttpProxyStrategyVtable{FCN}
    create_negotiator::FCN  # (strategy) -> HttpProxyNegotiator
end

mutable struct HttpProxyStrategy{VT <: HttpProxyStrategyVtable, Impl}
    vtable::VT
    impl::Impl
    proxy_connection_type::HttpProxyConnectionType.T
end

function http_proxy_strategy_create_negotiator(strategy::HttpProxyStrategy)::Union{HttpProxyNegotiator, Nothing}
    if strategy.vtable.create_negotiator !== nothing
        return strategy.vtable.create_negotiator(strategy)
    end
    return nothing
end

# ─── Proxy options ───

struct HttpProxyOptions{PS <: Union{HttpProxyStrategy, Nothing}}
    connection_type::HttpProxyConnectionType.T
    host::String
    port::UInt32
    proxy_strategy::PS
    auth_type::HttpProxyAuthenticationType.T  # deprecated
    auth_username::String  # deprecated
    auth_password::String  # deprecated
    no_proxy_hosts::String
end

function HttpProxyOptions(;
    connection_type::HttpProxyConnectionType.T=HttpProxyConnectionType.HTTP_LEGACY,
    host::String="",
    port::UInt32=UInt32(0),
    proxy_strategy::Union{HttpProxyStrategy, Nothing}=nothing,
    auth_type::HttpProxyAuthenticationType.T=HttpProxyAuthenticationType.NONE,
    auth_username::String="",
    auth_password::String="",
    no_proxy_hosts::String="",
)
    return HttpProxyOptions(
        connection_type, host, port,
        proxy_strategy,
        auth_type, auth_username, auth_password,
        no_proxy_hosts,
    )
end

function http_proxy_effective_connection_type(
        proxy_options::HttpProxyOptions,
        tls_connection_options,
    )::HttpProxyConnectionType.T
    if proxy_options.connection_type == HttpProxyConnectionType.HTTP_LEGACY
        return tls_connection_options === nothing ?
            HttpProxyConnectionType.HTTP_FORWARD :
            HttpProxyConnectionType.HTTP_TUNNEL
    end
    return proxy_options.connection_type
end

function http_proxy_strategy_from_options(
        proxy_options::HttpProxyOptions,
        tls_connection_options,
    )::Union{HttpProxyStrategy, Nothing}
    proxy_options.proxy_strategy !== nothing && return proxy_options.proxy_strategy
    proxy_connection_type = http_proxy_effective_connection_type(proxy_options, tls_connection_options)
    if proxy_options.auth_type == HttpProxyAuthenticationType.BASIC
        if !isempty(proxy_options.auth_username) && !isempty(proxy_options.auth_password)
            return http_proxy_strategy_new_basic_auth(
                HttpProxyStrategyBasicAuthOptions(
                    proxy_connection_type,
                    proxy_options.auth_username,
                    proxy_options.auth_password,
                ),
            )
        end
    end
    if proxy_connection_type == HttpProxyConnectionType.HTTP_FORWARD
        return http_proxy_strategy_new_forwarding_identity()
    elseif proxy_connection_type == HttpProxyConnectionType.HTTP_TUNNEL
        return http_proxy_strategy_new_tunneling_one_time_identity()
    end
    return nothing
end

# ─── Proxy config (persistent) ───

mutable struct HttpProxyConfig{PS <: Union{HttpProxyStrategy, Nothing}}
    connection_type::HttpProxyConnectionType.T
    host::String
    port::UInt32
    proxy_strategy::PS
    no_proxy_hosts::String
end

function http_proxy_config_new_from_proxy_options(options::HttpProxyOptions)::HttpProxyConfig
    strategy = http_proxy_strategy_from_options(options, nothing)
    return HttpProxyConfig(
        options.connection_type,
        options.host,
        options.port,
        strategy,
        options.no_proxy_hosts,
    )
end

function http_proxy_config_new_clone(config::HttpProxyConfig)::HttpProxyConfig
    return HttpProxyConfig(
        config.connection_type,
        config.host,
        config.port,
        config.proxy_strategy,
        config.no_proxy_hosts,
    )
end

function http_proxy_options_init_from_config(config::HttpProxyConfig)::HttpProxyOptions
    return HttpProxyOptions(
        connection_type=config.connection_type,
        host=config.host,
        port=config.port,
        proxy_strategy=config.proxy_strategy,
        no_proxy_hosts=config.no_proxy_hosts,
    )
end

# ─── Environment variable proxy settings ───

struct ProxyEnvVarSettings
    env_var_type::HttpProxyEnvVarType.T
    connection_type::HttpProxyConnectionType.T
end

function ProxyEnvVarSettings(;
    env_var_type::HttpProxyEnvVarType.T=HttpProxyEnvVarType.DISABLE,
    connection_type::HttpProxyConnectionType.T=HttpProxyConnectionType.HTTP_LEGACY,
)
    return ProxyEnvVarSettings(env_var_type, connection_type)
end

# ─── Built-in strategies ───

## Basic auth strategy

struct BasicAuthImpl
    user_name::String
    password::String
    proxy_connection_type::HttpProxyConnectionType.T
end

@enumx ProxyNegotiatorConnectState::UInt8 begin
    READY = 0
    IN_PROGRESS = 1
    SUCCESS = 2
    FAILURE = 3
end

function _proxy_negotiator_done(on_done, error_code::Int, user_data)::Nothing
    on_done !== nothing && on_done(error_code, user_data)
    return nothing
end

function _proxy_negotiator_forward(on_forward, message, user_data)::Nothing
    on_forward !== nothing && on_forward(message, user_data)
    return nothing
end

function _basic_auth_create_negotiator(strategy::HttpProxyStrategy)::HttpProxyNegotiator
    impl = strategy.impl::BasicAuthImpl
    encoded = Base64.base64encode(string(impl.user_name, ":", impl.password))

    if impl.proxy_connection_type == HttpProxyConnectionType.HTTP_FORWARD
        vtable = HttpProxyNegotiatorForwardingVtable(
            (negotiator, message) -> begin
                hdrs = http_message_get_headers(message)
                http_headers_add(hdrs, "Proxy-Authorization", "Basic $encoded")
                return OP_SUCCESS
            end,
        )
        return HttpProxyNegotiator(impl, false, vtable, nothing)
    else
        state = Ref(ProxyNegotiatorConnectState.READY)
        # Tunnelling: add auth to CONNECT request
        vtable = HttpProxyNegotiatorTunnellingVtable(
            (negotiator, message, on_done, on_forward, ud) -> begin
                if state[] != ProxyNegotiatorConnectState.READY
                    return _proxy_negotiator_done(on_done, ERROR_HTTP_PROXY_CONNECT_FAILED, ud)
                end
                state[] = ProxyNegotiatorConnectState.IN_PROGRESS
                hdrs = http_message_get_headers(message)
                status = http_headers_add(hdrs, "Proxy-Authorization", "Basic $encoded")
                if status != OP_SUCCESS
                    state[] = ProxyNegotiatorConnectState.FAILURE
                    return _proxy_negotiator_done(on_done, ERROR_HTTP_PROXY_CONNECT_FAILED, ud)
                end
                return _proxy_negotiator_forward(on_forward, message, ud)
            end,
            nothing,
            (negotiator, status_code) -> begin
                if state[] == ProxyNegotiatorConnectState.IN_PROGRESS
                    state[] = status_code == 200 ?
                        ProxyNegotiatorConnectState.SUCCESS :
                        ProxyNegotiatorConnectState.FAILURE
                end
                return OP_SUCCESS
            end,
            nothing,
            (_) -> HttpProxyNegotiationRetryDirective.STOP,
        )
        return HttpProxyNegotiator(impl, true, nothing, vtable)
    end
end

struct HttpProxyStrategyBasicAuthOptions
    proxy_connection_type::HttpProxyConnectionType.T
    user_name::String
    password::String
end

function http_proxy_strategy_new_basic_auth(options::HttpProxyStrategyBasicAuthOptions)::HttpProxyStrategy
    impl = BasicAuthImpl(options.user_name, options.password, options.proxy_connection_type)
    vtable = HttpProxyStrategyVtable(_basic_auth_create_negotiator)
    return HttpProxyStrategy(vtable, impl, options.proxy_connection_type)
end

## Identity strategy (forwarding)

function _forwarding_identity_create_negotiator(strategy::HttpProxyStrategy)::HttpProxyNegotiator
    vtable = HttpProxyNegotiatorForwardingVtable(
        (negotiator, message) -> OP_SUCCESS,
    )
    return HttpProxyNegotiator(nothing, false, vtable, nothing)
end

function http_proxy_strategy_new_forwarding_identity()::HttpProxyStrategy
    vtable = HttpProxyStrategyVtable(_forwarding_identity_create_negotiator)
    return HttpProxyStrategy(vtable, nothing, HttpProxyConnectionType.HTTP_FORWARD)
end

## Identity strategy (tunnelling, one-time)

function _tunneling_identity_create_negotiator(strategy::HttpProxyStrategy)::HttpProxyNegotiator
    state = Ref(ProxyNegotiatorConnectState.READY)
    vtable = HttpProxyNegotiatorTunnellingVtable(
        (negotiator, message, on_done, on_forward, ud) -> begin
            if state[] != ProxyNegotiatorConnectState.READY
                return _proxy_negotiator_done(on_done, ERROR_HTTP_PROXY_CONNECT_FAILED, ud)
            end
            state[] = ProxyNegotiatorConnectState.IN_PROGRESS
            return _proxy_negotiator_forward(on_forward, message, ud)
        end,
        nothing,
        (negotiator, status_code) -> begin
            if state[] == ProxyNegotiatorConnectState.IN_PROGRESS
                state[] = status_code == 200 ?
                    ProxyNegotiatorConnectState.SUCCESS :
                    ProxyNegotiatorConnectState.FAILURE
            end
            return OP_SUCCESS
        end,
        nothing,
        (_) -> HttpProxyNegotiationRetryDirective.STOP,
    )
    return HttpProxyNegotiator(nothing, true, nothing, vtable)
end

function http_proxy_strategy_new_tunneling_one_time_identity()::HttpProxyStrategy
    vtable = HttpProxyStrategyVtable(_tunneling_identity_create_negotiator)
    return HttpProxyStrategy(vtable, nothing, HttpProxyConnectionType.HTTP_TUNNEL)
end

## Sequence strategy (tunnelling)

struct SequenceImpl
    strategies::Vector{HttpProxyStrategy}
end

function _sequence_create_negotiator(strategy::HttpProxyStrategy)::HttpProxyNegotiator
    impl = strategy.impl::SequenceImpl
    # Create negotiators for all sub-strategies
    sub_negotiators = HttpProxyNegotiator[]
    for sub in impl.strategies
        neg = http_proxy_strategy_create_negotiator(sub)
        neg !== nothing && push!(sub_negotiators, neg)
    end

    current_idx = Ref(1)
    active_on_done = Ref{Any}(nothing)
    active_on_forward = Ref{Any}(nothing)
    active_user_data = Ref{Any}(nothing)

    vtable = HttpProxyNegotiatorTunnellingVtable(
        (negotiator, message, on_done, on_forward, ud) -> begin
            active_on_done[] = on_done
            active_on_forward[] = on_forward
            active_user_data[] = ud

            if current_idx[] > length(sub_negotiators)
                return _proxy_negotiator_done(on_done, ERROR_HTTP_PROXY_CONNECT_FAILED, ud)
            end

            sub = sub_negotiators[current_idx[]]
            current_idx[] += 1

            if sub.is_tunnelling && sub.tunnelling_vtable !== nothing &&
               sub.tunnelling_vtable.connect_request_transform !== nothing
                wrapped_on_done = (args...) -> begin
                    mapped_error = current_idx[] <= length(sub_negotiators) ?
                        ERROR_HTTP_PROXY_CONNECT_FAILED_RETRYABLE :
                        ERROR_HTTP_PROXY_CONNECT_FAILED
                    return _proxy_negotiator_done(active_on_done[], mapped_error, active_user_data[])
                end
                wrapped_on_forward = (forwarded_message, args...) -> begin
                    return _proxy_negotiator_forward(active_on_forward[], forwarded_message, active_user_data[])
                end
                sub.tunnelling_vtable.connect_request_transform(sub, message, wrapped_on_done, wrapped_on_forward, ud)
            else
                _proxy_negotiator_forward(on_forward, message, ud)
            end
            return nothing
        end,
        (negotiator, header_block, headers) -> begin
            for sub in sub_negotiators
                if sub.is_tunnelling && sub.tunnelling_vtable !== nothing
                    cb = sub.tunnelling_vtable.on_incoming_headers
                    cb !== nothing && cb(sub, header_block, headers)
                end
            end
            return OP_SUCCESS
        end,
        (negotiator, status_code) -> begin
            for sub in sub_negotiators
                if sub.is_tunnelling && sub.tunnelling_vtable !== nothing
                    cb = sub.tunnelling_vtable.on_status
                    cb !== nothing && cb(sub, status_code)
                end
            end
            return OP_SUCCESS
        end,
        (negotiator, data) -> begin
            for sub in sub_negotiators
                if sub.is_tunnelling && sub.tunnelling_vtable !== nothing
                    cb = sub.tunnelling_vtable.on_incoming_body
                    cb !== nothing && cb(sub, data)
                end
            end
            return OP_SUCCESS
        end,
        (negotiator) -> begin
            if current_idx[] <= length(sub_negotiators)
                next_negotiator = sub_negotiators[current_idx[]]
                next_directive = http_proxy_negotiator_get_retry_directive(next_negotiator)
                if next_directive == HttpProxyNegotiationRetryDirective.CURRENT_CONNECTION
                    return HttpProxyNegotiationRetryDirective.CURRENT_CONNECTION
                end
                return HttpProxyNegotiationRetryDirective.NEW_CONNECTION
            end
            return HttpProxyNegotiationRetryDirective.STOP
        end,
    )
    return HttpProxyNegotiator(
        (sub_negotiators, current_idx, active_on_done, active_on_forward, active_user_data),
        true,
        nothing,
        vtable,
    )
end

function http_proxy_strategy_new_tunneling_sequence(strategies::AbstractVector{<:HttpProxyStrategy})::HttpProxyStrategy
    vtable = HttpProxyStrategyVtable(_sequence_create_negotiator)
    return HttpProxyStrategy(vtable, SequenceImpl(HttpProxyStrategy[strategies...]), HttpProxyConnectionType.HTTP_TUNNEL)
end

# ─── No-proxy matching ───

"""
    http_host_matches_no_proxy(host, no_proxy) -> Bool

Check if a host matches any pattern in a comma-separated no-proxy list.
Supports domain suffix matching, IP address matching, CIDR matching, and wildcard ("*").
"""
function _no_proxy_is_ascii_digits(value::AbstractString)::Bool
    isempty(value) && return false
    for c in value
        if c < '0' || c > '9'
            return false
        end
    end
    return true
end

function _no_proxy_strip_host_port(host::AbstractString)::String
    host_value = String(host)
    isempty(host_value) && return host_value
    if startswith(host_value, '[')
        close_idx = findfirst(==(']'), host_value)
        if close_idx !== nothing && close_idx > 1
            inner_host = host_value[2:close_idx - 1]
            if close_idx == lastindex(host_value)
                return inner_host
            end
            if close_idx < lastindex(host_value) && host_value[close_idx + 1] == ':'
                port_value = host_value[close_idx + 2:end]
                _no_proxy_is_ascii_digits(port_value) && return inner_host
            end
        end
        return host_value
    end
    count(==(':'), host_value) == 1 || return host_value
    colon_idx = findlast(==(':'), host_value)
    colon_idx === nothing && return host_value
    colon_idx <= 1 && return host_value
    colon_idx >= lastindex(host_value) && return host_value
    port_value = host_value[colon_idx + 1:end]
    _no_proxy_is_ascii_digits(port_value) || return host_value
    return host_value[1:colon_idx - 1]
end

function _no_proxy_try_parse_ipv4(value::AbstractString)::Union{Sockets.IPv4, Nothing}
    try
        return parse(Sockets.IPv4, value)
    catch
        return nothing
    end
end

function _no_proxy_try_parse_ipv6(value::AbstractString)::Union{Sockets.IPv6, Nothing}
    try
        return parse(Sockets.IPv6, value)
    catch
        return nothing
    end
end

function _no_proxy_match_cidr4(
        host_ip::Sockets.IPv4,
        network_ip::Sockets.IPv4,
        bit_count::Union{Int, Nothing},
    )::Bool
    bit_count === nothing && return host_ip == network_ip
    (bit_count < 0 || bit_count > 32) && return false
    if bit_count == 0 || bit_count == 32
        return host_ip == network_ip
    end
    host_value = reinterpret(UInt32, host_ip)
    network_value = reinterpret(UInt32, network_ip)
    mask = typemax(UInt32) << (32 - bit_count)
    return (host_value & mask) == (network_value & mask)
end

function _no_proxy_match_cidr6(
        host_ip::Sockets.IPv6,
        network_ip::Sockets.IPv6,
        bit_count::Union{Int, Nothing},
    )::Bool
    bit_count === nothing && return host_ip == network_ip
    bit_count == 0 && (bit_count = 128)
    (bit_count < 0 || bit_count > 128) && return false
    if bit_count == 128
        return host_ip == network_ip
    end
    host_value = reinterpret(UInt128, host_ip)
    network_value = reinterpret(UInt128, network_ip)
    mask = typemax(UInt128) << (128 - bit_count)
    return (host_value & mask) == (network_value & mask)
end

function http_host_matches_no_proxy(host::AbstractString, no_proxy::AbstractString)::Bool
    isempty(no_proxy) && return false
    isempty(host) && return false

    no_proxy_value = strip(String(no_proxy))
    no_proxy_value == "*" && return true

    host_value = lowercase(strip(_no_proxy_strip_host_port(host)))
    isempty(host_value) && return false

    host_candidate = if startswith(host_value, '[') && endswith(host_value, ']') && ncodeunits(host_value) > 2
        host_value[2:end - 1]
    else
        host_value
    end

    host_ipv4 = _no_proxy_try_parse_ipv4(host_candidate)
    host_ipv6 = host_ipv4 === nothing ? _no_proxy_try_parse_ipv6(host_candidate) : nothing

    if host_ipv4 === nothing && host_ipv6 === nothing
        host_regular = rstrip(host_candidate, '.')
        isempty(host_regular) && return false
        for entry in eachsplit(no_proxy_value, ',')
            pattern = lowercase(strip(String(entry)))
            isempty(pattern) && continue
            pattern_regular = strip(pattern, '.')
            isempty(pattern_regular) && continue
            if host_regular == pattern_regular
                return true
            end
            if endswith(host_regular, string('.', pattern_regular))
                return true
            end
        end
        return false
    end

    if host_ipv4 !== nothing
        host_ip = host_ipv4::Sockets.IPv4
        for entry in eachsplit(no_proxy_value, ',')
            pattern = lowercase(strip(String(entry)))
            isempty(pattern) && continue
            pattern_parts = split(pattern, '/'; limit = 2)
            network_part = strip(pattern_parts[1])
            isempty(network_part) && continue
            bit_count = nothing
            if length(pattern_parts) == 2
                bit_count = tryparse(Int, strip(pattern_parts[2]))
                bit_count === nothing && continue
            end
            network_ip = _no_proxy_try_parse_ipv4(network_part)
            network_ip === nothing && continue
            if _no_proxy_match_cidr4(host_ip, network_ip, bit_count)
                return true
            end
        end
        return false
    end

    host_ip = host_ipv6::Sockets.IPv6
    for entry in eachsplit(no_proxy_value, ',')
        pattern = lowercase(strip(String(entry)))
        isempty(pattern) && continue
        pattern_parts = split(pattern, '/'; limit = 2)
        network_part = strip(pattern_parts[1])
        isempty(network_part) && continue
        bit_count = nothing
        if length(pattern_parts) == 2
            bit_count = tryparse(Int, strip(pattern_parts[2]))
            bit_count === nothing && continue
        end
        network_ip = _no_proxy_try_parse_ipv6(network_part)
        network_ip === nothing && continue
        if _no_proxy_match_cidr6(host_ip, network_ip, bit_count)
            return true
        end
    end
    return false
end

# ─── Rewrite URI for forward proxy ───

"""
    http_rewrite_uri_for_proxy_request(request, host, port) -> Int

Rewrite the request path to an absolute URI for forward proxy.
"""
function http_rewrite_uri_for_proxy_request(request::HttpMessage, host::AbstractString, port::UInt32)::Int
    path = http_message_get_request_path(request)
    path === nothing && return raise_error(ERROR_INVALID_STATE)

    # Build absolute URI
    scheme = "http"
    abs_uri = if port == UInt32(80) || port == UInt32(0)
        string(scheme, "://", host, path)
    else
        string(scheme, "://", host, ":", port, path)
    end

    return http_message_set_request_path(request, abs_uri)
end
