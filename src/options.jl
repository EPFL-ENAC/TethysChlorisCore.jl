abstract type AbstractOptions end
abstract type AbstractModelOptions <: AbstractOptions end
abstract type AbstractODEOptions <: AbstractOptions end

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
