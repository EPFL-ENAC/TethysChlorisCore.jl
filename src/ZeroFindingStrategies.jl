abstract type AbstractZeroFindingStrategies <: AbstractOptions end

"""
    ZeroFindingStrategies{M} <: AbstractZeroFindingStrategies

# Fields
- `method::M`: Method for root finding
- `kwargs::NamedTuple`: Keyword arguments for the root finding method

# Example
```julia
strategy = SimpleBrentStrategy(Float64; abstol=1e-8, reltol=1e-6, maxiters=500)
```
"""

struct ZeroFindingStrategies{M} <: AbstractZeroFindingStrategies
    method::M
    kwargs::NamedTuple
end

"""
    function SimpleBrentStrategy(
        ::Type{FT};
        abstol::Union{FT,Missing}=missing,
        reltol::Union{FT,Missing}=missing,
        maxiters::Union{Signed,Missing}=missing,
    ) where {FT<:AbstractFloat}

Creates a `ZeroFindingStrategies` object using the Simple Brent method from the
`BracketingNonlinearSolve.jl` package.

# Arguments
- `::Type{FT}`: Floating point type for the root finding method (e.g., `Float32` or `Float64`)
- `abstol::Union{FT,Missing}`: Absolute tolerance for the root finding. If `missing`, the
    default value for the method is used.
- `reltol::Union{FT,Missing}`: Relative tolerance for the root finding. If `missing`, the
    default value for the method is used.
- `maxiters::Union{Signed,Missing}`: Maximum number of iterations. If `missing`, the default
    value for the method is used.
"""
function SimpleBrentStrategy(
    ::Type{FT};
    abstol::Union{FT,Missing}=missing,
    reltol::Union{FT,Missing}=missing,
    maxiters::Union{Signed,Missing}=missing,
) where {FT<:AbstractFloat}

    # Returns abstol, reltol, maxiters
    defaults = default_tolerances(SimpleNonlinearSolve.Brent(), FT)

    abstol = ismissing(abstol) ? defaults[1] : abstol
    reltol = ismissing(reltol) ? defaults[2] : reltol
    maxiters = ismissing(maxiters) ? defaults[3] : maxiters

    return ZeroFindingStrategies(SimpleNonlinearSolve.Brent(), (; abstol, reltol, maxiters))
end

"""
    default_tolerances(
        method::M,
        ::Type{FT},
    ) where {FT<:AbstractFloat}

Get default tolerances for SimpleNonlinearSolve.jl and BracketingNonlinearSolve.jl methods.
The default tolerances are hard-coded based on the documentation of NonlinearSolve.jl.

# Arguments
- `method::M`: The root-finding method
- `::Type{FT}`: Floating point type

# Returns
- `(abstol, reltol, maxiters)`: Tuple containing the default absolute tolerance, relative tolerance, and maximum iterations

"""
# Internal helper
function _default_tolerances_simple(::Type{FT}) where {FT<:AbstractFloat}
    abstol = real(oneunit(FT)) * (eps(real(one(FT))))^(4 // 5)
    reltol = real(oneunit(FT)) * (eps(real(one(FT))))^(4 // 5)
    maxiters = 1000
    return (abstol, reltol, maxiters)
end

function default_tolerances(
    method::AbstractSimpleNonlinearSolveAlgorithm, ::Type{FT}
) where {FT<:AbstractFloat}
    return _default_tolerances_simple(FT)
end

# for Brent in SimpleNonlinear Solve
function default_tolerances(
    method::AbstractBracketingAlgorithm, ::Type{FT}
) where {FT<:AbstractFloat}
    return _default_tolerances_simple(FT)
end
