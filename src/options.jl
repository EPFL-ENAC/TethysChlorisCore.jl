abstract type AbstractOptions end
abstract type AbstractModelOptions <: AbstractOptions end
abstract type AbstractODEOptions <: AbstractOptions end
abstract type AbstractZeroFindingStrategies <: AbstractOptions end

"""
    ODEOptions <: AbstractODEOptions

# Fields
- `abstol::AbstractFloat`: Absolute tolerance for the ODE solver (default: 1e-6)
- `reltol::AbstractFloat`: Relative tolerance for the ODE solver (default: 1e-3)

# Notes
The default values for the absolute and relative tolerances are chosen to replicate the
behavior of the MATLAB [`odeset`](https://ch.mathworks.com/help/matlab/ref/odeset.html#d126e1217941) defaults.
"""
Base.@kwdef struct ODEOptions <: AbstractODEOptions
    abstol::AbstractFloat = 1e-6
    reltol::AbstractFloat = 1e-3
end

"""
    ZeroFindingStrategies <: AbstractZeroFindingStrategies

# Fields
- `method::Roots.AbstractUnivariateZeroMethod`: Method for root finding (default: `Roots.Order0()`)
- `xatol::AbstractFloat`: Absolute tolerance for the root finding (default: method-dependent)
- `xrtol::AbstractFloat`: Relative tolerance for the root finding (default: method-dependent)
- `atol::AbstractFloat`: Absolute tolerance for the function value (default: method-dependent)
- `rtol::AbstractFloat`: Relative tolerance for the function value (default: method-dependent)
- `maxiters::Int`: Maximum number of iterations (default: method-dependent)

# Example
```julia
opt = RootsBracketingStrategy(FT, Brent(); rtol = 0.1)
```
"""
struct ZeroFindingStrategies{M} <: AbstractZeroFindingStrategies
    method::M
    kwargs::NamedTuple
end

"""
    find_root(
        f,
        x0,
        strategy::ZeroFindingStrategies{M};
        search_range = nothing,
    ) where {M}

Wrapper function to find a root of the function `f` using the specified `strategy`, given an
initial guess `x0`. Current implementations exists for both `Roots.jl` and
`SimpleNonlinearSolve.jl` strategies.

# Arguments
- `f`: Function for which to find a root
- `x0`: Initial guess for the root
- `strategy::ZeroFindingStrategies{M}`: Strategy for root finding
- `search_range`: Optional search range for bracketing methods (default: `nothing`)
"""
function find_root(f, x0, strategy::ZeroFindingStrategies{M}; kwargs...) where {M}
    throw(
        MethodError(
            "No method defined for find_root with strategy of type $(typeof(strategy))"
        ),
    )
end
