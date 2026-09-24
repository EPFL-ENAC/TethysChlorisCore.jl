abstract type AbstractOutputsToSave end

struct NoOutputs <: AbstractOutputsToSave end
struct AllOutputs <: AbstractOutputsToSave end
const no_outputs = NoOutputs()

# Storage frequency types
abstract type AbstractStorageFrequency end
struct HourlyStorage <: AbstractStorageFrequency end
struct DailyStorage <: AbstractStorageFrequency end
struct StaticStorage <: AbstractStorageFrequency end
struct NoStorage <: AbstractStorageFrequency end

const hourly_storage = HourlyStorage()
const daily_storage = DailyStorage()
const static_storage = StaticStorage()
const no_storage = NoStorage()

"""
    storage_frequency(::Type{T}) where {T <: AbstractModelComponent}

Return the storage frequency for component type T.

This trait function determines how often component outputs should be stored during
simulation. Components can be stored at different temporal frequencies:
- `HourlyStorage()`: Store values every timestep (hourly data)
- `DailyStorage()`: Store values once per day (daily aggregates)
- `NoStorage()`: Do not store this component (default)

# Default Behavior
By default, components return `NoStorage()`, implementing an opt-in approach where
only components with explicitly defined storage frequencies will be saved.

# Examples
```julia
# Define storage frequency for specific component types
storage_frequency(::Type{HydrologicState}) = hourly_storage
storage_frequency(::Type{VegetationState}) = daily_storage
storage_frequency(::Type{AuxiliaryVariables}) = no_storage  # Not stored

# Components without explicit definitions default to no_storage
storage_frequency(::Type{SomeOtherComponent})  # Returns no_storage
```
"""
storage_frequency(::Type{<:AbstractModelComponent}) = no_storage

"""
    storage_size(frequency::AbstractStorageFrequency, n_timesteps::Int) -> Int

Calculate the required array size based on storage frequency and total timesteps.

# Arguments
- `frequency::AbstractStorageFrequency`: The storage frequency (Hourly, Daily, or NoStorage)
- `n_timesteps::Int`: Total number of hourly timesteps in the simulation

# Returns
- `Int`: The required array size for the given frequency

# Sizing Logic
- `HourlyStorage`: `n_timesteps` (one entry per hourly timestep)
- `DailyStorage`: `div(n_timesteps, 24, RoundUp) + 2` (one entry per day plus buffer)
- `NoStorage`: `0` (no storage needed)

# Daily Storage Buffer
The `+2` buffer in daily storage provides extra space for:
- Index 1: Initialization values
- Index N+1: Boundary/final day handling
This matches the pattern used in TethysChloris.jl for consistency.

# Examples
```julia
# Hourly storage for 720 timesteps (30 days)
storage_size(HourlyStorage(), 720)  # Returns 720

# Daily storage for 720 timesteps (30 days)
storage_size(DailyStorage(), 720)   # Returns 32 (30 days + 2 buffer)

# Daily storage for 721 timesteps (30 days + 1 hour)
storage_size(DailyStorage(), 721)   # Returns 33 (31 days + 2 buffer, rounded up)

# No storage
storage_size(NoStorage(), 1000)     # Returns 0
```
"""
storage_size(::HourlyStorage, n_timesteps::Int) = n_timesteps
storage_size(::DailyStorage, n_timesteps::Int) = div(n_timesteps, 24, RoundUp) + 2
storage_size(::StaticStorage, n_timesteps::Int) = 0  # No time series allocation
storage_size(::NoStorage, n_timesteps::Int) = 0

function decrease(::Type{T}) where {T<:AbstractOutputsToSave}
    throw(ArgumentError("No method defined for decrease with type $(T)"))
end

"""
    outputs_to_save(::Type{T}, ::Type{O}) where {T, O <: AbstractOutputsToSave}

Get the outputs to save for type `T` corresponding to the outputs level `O`.

This function is called recursively at each level of the type hierarchy to enable
fine-grained control over which fields to save. For types with height-dependent
structure (containing both `:high` and `:low` fields), this function is called
at multiple levels:

1. At the parent level: returns which components to include (e.g., `(:scalar_field, :high, :low)`)
2. At the height-dependent level: returns which fields from the nested type (e.g., `(:field1,)`)

The accessor system uses these specifications to create accessor functions with appropriate
suffixes for height-dependent fields (`_H` for high, `_L` for low).

# Arguments
- `T::Type{T}`: The model component type
- `O::Type{O}`: The outputs to save type (subtype of `AbstractOutputsToSave`)

# Returns
- `Tuple{Vararg{Symbol}}`: Tuple of field names to save from type `T`
- Empty tuple `()` means no fields from this type (strict mode: no accessors created)

# Strict Mode
If `outputs_to_save` returns `()` for a type that has been selected at a parent level,
no accessors will be created for that component. This requires explicit specification
of which fields to save at each level of the hierarchy.

# Examples
```julia
# Example type hierarchy
struct HeightDependentHydrologicStateVariables{FT}
    field1::Vector{FT}
    field2::Vector{FT}
    field3::Vector{FT}
end

struct HydrologicStateVariables{FT}
    scalar_field::Vector{FT}
    high::HeightDependentHydrologicStateVariables{FT}
    low::HeightDependentHydrologicStateVariables{FT}
end

struct StateVariableSet{FT}
    hydrologic::HydrologicStateVariables{FT}
end

# Define output levels
struct SimpleOutputs <: AbstractOutputsToSave end
struct ExtendedOutputs <: AbstractOutputsToSave end

# Level 1: Select which top-level components
outputs_to_save(::Type{StateVariableSet}, ::Type{SimpleOutputs}) = (:hydrologic,)

# Level 2: Select which fields from the component (including :high, :low)
outputs_to_save(::Type{HydrologicStateVariables}, ::Type{SimpleOutputs}) =
    (:scalar_field, :high, :low)

# Level 3: Select which fields from height-dependent component
outputs_to_save(::Type{HeightDependentHydrologicStateVariables}, ::Type{SimpleOutputs}) =
    (:field1,)

# For ExtendedOutputs, include more fields at level 3
outputs_to_save(::Type{HeightDependentHydrologicStateVariables}, ::Type{ExtendedOutputs}) =
    (:field1, :field2)

# Result for SimpleOutputs:
# Dict(:hydrologic => Dict(:scalar_field => fn, :field1_H => fn, :field1_L => fn))

# Result for ExtendedOutputs:
# Dict(:hydrologic => Dict(:scalar_field => fn, :field1_H => fn, :field1_L => fn,
#                          :field2_H => fn, :field2_L => fn))
```

# Independent Control
Direct fields (not in `:high`/`:low`) and height-dependent fields can be controlled
independently:

```julia
# Include only direct fields, no height layers
outputs_to_save(::Type{HydrologicStateVariables}, ::Type{DirectOnly}) = (:scalar_field,)

# Include only height layers, no direct fields
outputs_to_save(::Type{HydrologicStateVariables}, ::Type{HeightOnly}) = (:high, :low)
outputs_to_save(::Type{HeightDependentHydrologicStateVariables}, ::Type{HeightOnly}) = (:field1,)

# Include only high layer, not low
outputs_to_save(::Type{HydrologicStateVariables}, ::Type{HighOnly}) = (:scalar_field, :high)
outputs_to_save(::Type{HeightDependentHydrologicStateVariables}, ::Type{HighOnly}) = (:field1,)
```

# Note
This function is expected to be overloaded for specific types and output levels.
The default implementation returns an empty tuple `()`.
"""
function outputs_to_save(::Type{T}, ::Type{O}) where {T,O<:AbstractOutputsToSave}
    return ()
end

function outputs_to_save(::Type{T}) where {T}
    return fieldnames(T)
end
