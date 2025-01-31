# This file is part of the IntervalArithmetic.jl package; MIT licensed

# The order in which files are included is important,
# since certain things need to be defined before others use them

## Interval type

if haskey(ENV, "IA_VALID") == true
    const validity_check = true
else
    const validity_check = false
end

abstract type AbstractInterval{T} <: Real end

struct Interval{T<:Real} <: AbstractInterval{T}
    lo :: T
    hi :: T

    function Interval{T}(a::Real, b::Real) where T<:Real

        a = _normalisezero(a)
        b = _normalisezero(b)

        if validity_check

            if is_valid_interval(a, b)
                return new(a, b)

            else
                @warn "Invalid input, empty interval is returned"
                return new(T(Inf), T(-Inf))
            end

        end

        new(a, b)

    end
end

@inline _normalisezero(a::Real) = ifelse(iszero(a) && signbit(a), copysign(a, 1), a)


## Outer constructors

Interval(a::T, b::T) where T<:Real = Interval{T}(a, b)
Interval(a::T) where T<:Real = Interval(a, a)
Interval(a::Tuple) = Interval(a...)
Interval(a::T, b::S) where {T<:Real, S<:Real} = Interval(promote(a,b)...)

## Concrete constructors for Interval, to effectively deal only with Float64,
# BigFloat or Rational{Integer} intervals.
Interval(a::T, b::T) where T<:Integer = Interval(float(a), float(b))

# Constructors for Irrational
# Single argument Irrational constructor are in IntervalArithmetic.jl
# as generated functions need to be define last.
Interval{T}(a::Irrational, b::Irrational) where {T<:Real} = Interval{T}(T(a, RoundDown), T(b, RoundUp))
Interval{T}(a::Irrational, b::Real) where {T<:Real} = Interval{T}(T(a, RoundDown), b)
Interval{T}(a::Real, b::Irrational) where {T<:Real} = Interval{T}(a, T(b, RoundUp))

Interval(a::Irrational, b::Irrational) = Interval{Float64}(a, b)
Interval(a::Irrational, b::Real) = Interval{Float64}(a, b)
Interval(a::Real, b::Irrational) = Interval{Float64}(a, b)

Interval(x::Interval) = x
Interval(x::Complex) = Interval(real(x)) + im*Interval(imag(x))

Interval{T}(x) where T = Interval(convert(T, x))

Interval{T}(x::Interval) where T = atomic(Interval{T}, x)

size(x::Interval) = (1,)


"""
    is_valid_interval(a::Real, b::Real)

Check if `(a, b)` constitute a valid interval
"""
function is_valid_interval(a::Real, b::Real)

    # println("isvalid()")

    if isnan(a) || isnan(b)
        return false
    end

    a > b && return false

    if a == Inf || b == -Inf
        return false
    end

    return true
end

"""
    interval(a, b)

`interval(a, b)` checks whether [a, b] is a valid `Interval`, using the (non-exported) `is_valid_interval` function. If so, then an `Interval(a, b)` object is returned; if not, a warning is printed and the empty interval is returned.
"""
function interval(a::T, b::S) where {T<:Real, S<:Real}
    if !is_valid_interval(a, b)
        @warn "Invalid input, empty interval is returned"
        return emptyinterval(promote_type(T, S))
    end

    return Interval(a, b)
end

interval(a::Real) = interval(a, a)
interval(a::Interval) = a

"Make an interval even if a > b"
function force_interval(a, b)
    a > b && return interval(b, a)
    return interval(a, b)
end


## Include files
include("special.jl")
include("macros.jl")
include("rounding_macros.jl")
include("rounding.jl")
include("conversion.jl")
include("precision.jl")
include("set_operations.jl")
include("arithmetic.jl")
include("functions.jl")
include("trigonometric.jl")
include("hyperbolic.jl")
include("complex.jl")

# Syntax for intervals

function ..(a::T, b::S) where {T, S}
    if !is_valid_interval(a, b)
        @warn "Invalid input, empty interval is returned"
        return emptyinterval(promote_type(T, S))
    end
    Interval(atomic(Interval{T}, a).lo, atomic(Interval{S}, b).hi)
end

function ..(a::T, b::Irrational{S}) where {T, S}
    if !is_valid_interval(a, b)
        @warn "Invalid input, empty interval is returned"
        return emptyinterval(promote_type(T, Irrational{S}))
    end
    R = promote_type(T, Irrational{S})
    Interval(atomic(Interval{R}, a).lo, R(b, RoundUp))
end

function ..(a::Irrational{T}, b::S) where {T, S}
    if !is_valid_interval(a, b)
        @warn "Invalid input, empty interval is returned"
        return emptyinterval(promote_type(Irrational{T}, S))
    end
    R = promote_type(Irrational{T}, S)
    return Interval(R(a, RoundDown), atomic(Interval{R}, b).hi)
end

function ..(a::Irrational{T}, b::Irrational{S}) where {T, S}
    return interval(a, b)
end

# ..(a::Integer, b::Integer) = interval(a, b)
# ..(a::Integer, b::Real) = interval(a, nextfloat(float(b)))
# ..(a::Real, b::Integer) = interval(prevfloat(float(a)), b)
#
# ..(a::Real, b::Real) = interval(prevfloat(float(a)), nextfloat(float(b)))

macro I_str(ex)  # I"[3,4]"
    @interval(ex)
end

a ± b = (a-b)..(a+b)
±(a::Interval, b) = (a.lo - b)..(a.hi + b)

"""
Computes the integer hash code for an `Interval` using the method for composite types used in `AutoHashEquals.jl`
"""
hash(x::Interval, h::UInt) = hash(x.hi, hash(x.lo, hash(:Interval, h)))
