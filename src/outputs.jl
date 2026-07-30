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

"""
    allocate_results_from_accessors(
        accessors_dict::Dict{Symbol,Dict{Symbol,Function}},
        model::M,
        n_timesteps::Int;
        frequency::AbstractStorageFrequency = HourlyStorage()
    ) where {M}

Allocate arrays for storing simulation results based on an existing accessor dictionary.
This ensures perfect key alignment between accessors and result arrays.

This function is used internally by `allocate_results` and can be called directly
from `prepare_results` to avoid creating the accessor dictionary twice.

# Arguments
- `accessors_dict::Dict{Symbol,Dict{Symbol,Function}}`: Accessor dictionary created by `accessors(T, O)`
- `model::M`: The model instance (used to extract field values via accessors)
- `n_timesteps::Int`: Number of timesteps in the simulation
- `frequency::AbstractStorageFrequency`: Storage frequency (default: `HourlyStorage()`)

# Returns
- `Dict{Symbol,Dict{Symbol,Array}}`: Nested dictionary of pre-allocated arrays with
  keys exactly matching the accessor dictionary

# Examples
```julia
# Create accessors first
accessor_dict = accessors(StateVariableSet{Float64}, SimpleOutputs)

# Allocate results with matching structure (hourly by default)
results = allocate_results_from_accessors(accessor_dict, model, 720)

# Allocate with daily frequency
results_daily = allocate_results_from_accessors(
    accessor_dict, model, 720; frequency=DailyStorage()
)  # Arrays sized for 32 days (720/24 + 2)

# Keys are guaranteed to match
@assert keys(results) == keys(accessor_dict)
for component in keys(results)
    @assert keys(results[component]) == keys(accessor_dict[component])
end
```

"""
function allocate_results_from_accessors(
    accessors_dict::Dict{Symbol,Dict{Symbol,Function}},
    model::M,
    n_timesteps::Int;
    frequency::AbstractStorageFrequency=HourlyStorage(),
) where {M}
    results = Dict{Symbol,Dict{Symbol,Array}}()

    # Calculate the storage size based on frequency
    array_size = storage_size(frequency, n_timesteps)

    for (component_field, field_accessors) in accessors_dict
        component_results = Dict{Symbol,Array}()

        for (field_key, accessor_fn) in field_accessors
            # Use the accessor to extract the actual value from the model
            field_value = accessor_fn(model)
            # Allocate array based on the extracted value's type and shape
            component_results[field_key] = _allocate_field_array(field_value, array_size)
        end

        results[component_field] = component_results
    end

    return results
end

function _allocate_field_array(field_instance::Number, n_timesteps::Int)
    return zeros(typeof(field_instance), n_timesteps)
end

function _allocate_field_array(field_instance::AbstractVector, n_timesteps::Int)
    return zeros(eltype(field_instance), n_timesteps, length(field_instance))
end

function _allocate_field_array(
    field_instance::SVector{N,Number}, n_timesteps::Int
) where {N}
    return zeros(eltype(field_instance), n_timesteps, N)
end

function _allocate_field_array(
    field_instance::MVector{N,Number}, n_timesteps::Int
) where {N}
    return zeros(eltype(field_instance), n_timesteps, N)
end

function _allocate_field_array(field_instance::AbstractArray, n_timesteps::Int)
    return zeros(eltype(field_instance), n_timesteps, size(field_instance)...)
end

"""
    allocate_static_results_from_accessors(
        accessors_dict::Dict{Symbol,Dict{Symbol,Function}},
        model::M
    ) where {M}

Allocate storage for static (non-time-varying) results.
Instead of arrays, creates a nested Dict structure with deepcopy of values.

Static storage is used for parameters and forcing inputs that don't change
during the simulation. Values are copied once at initialization rather than
being accessed at each timestep.

# Arguments
- `accessors_dict::Dict{Symbol,Dict{Symbol,Function}}`: Accessor dictionary
- `model::M`: The model instance (used to extract field values via accessors)

# Returns
- `Dict{Symbol,Dict{Symbol,Any}}`: Nested dictionary with static values

# Examples
```julia
# Create accessors for parameters
param_accessors = accessors(ParameterSet{Float64}, AllOutputs)

# Allocate static storage
static_results = allocate_static_results_from_accessors(param_accessors, model.parameters)

# Access static values
Zs = static_results[:simulation][:Zs]
```
"""
function allocate_static_results_from_accessors(
    accessors_dict::Dict{Symbol,Dict{Symbol,Function}}, model::M
) where {M}
    results = Dict{Symbol,Dict{Symbol,Any}}()

    for (component_key, component_accessors) in accessors_dict
        component_results = Dict{Symbol,Any}()

        for (field_key, accessor_fn) in component_accessors
            # Get value and deepcopy for safety
            value = accessor_fn(model)
            component_results[field_key] = deepcopy(value)
        end

        results[component_key] = component_results
    end

    return results
end

"""
    prepare_component_results(::Type{T}, ::Type{O}, model_component::M, n_timesteps::Int) where {T,O,M}

Prepare both accessor functions and pre-allocated result arrays for a simulation.
This is an optimized convenience function that creates the accessor dictionary once
and reuses it for both access and allocation.

# Arguments
- `T::Type{T}`: The model component type (e.g., `StateVariableSet`)
- `O::Type{O}`: The outputs to save type (e.g., `SimpleOutputs`, `AllOutputs`)
- `model_component::M`: The model component instance
- `n_timesteps::Int`: Number of timesteps in the simulation

# Returns
- `Tuple{Dict{Symbol,Dict{Symbol,Array}}, Dict{Symbol,Dict{Symbol,Function}}}`:
  A tuple of (results, accessors) where:
  - `results`: Pre-allocated arrays for storing values at each timestep
  - `accessors`: Functions for extracting values from the model

# Examples
```julia
# Prepare for simulation
results, accessors_dict = prepare_component_results(
    StateVariableSet{Float64},
    SimpleOutputs,
    model_component,
    1000
)

# During simulation, assign values at each timestep
for timestep in 1:1000
    # Update model state...
    assign_component_results!(results, accessors_dict, model_component, timestep)
end
```
"""
function prepare_component_results(
    ::Type{T}, ::Type{O}, model_component::M, n_timesteps::Int
) where {T,O,M}
    accessors_dict = accessors(T, O)
    results = allocate_results_from_accessors(accessors_dict, model_component, n_timesteps)

    return results, accessors_dict
end

"""
    prepare_results(::Type{T}, ::Type{O}, model, n_timesteps::Int) where {T,O}

Prepare results dictionary grouped by storage frequency with pre-computed accessors.

This function analyzes component-level storage frequencies and groups outputs accordingly,
allocating arrays with frequency-appropriate sizes. Components are grouped into hourly
and daily storage categories based on their `storage_frequency` trait.

# Arguments
- `T::Type{T}`: The model component set type (e.g., `StateVariableSet`)
- `O::Type{O}`: The outputs to save type (e.g., `AllOutputs`, `SimpleOutputs`)
- `model`: The model instance containing all components
- `n_timesteps::Int`: Total number of hourly timesteps in the simulation

# Returns
- `Tuple{Dict{Symbol,Dict}, Dict{Symbol,Dict}}`: A tuple of (results, accessors) where:
  - `results`: Nested dictionary with structure `Dict(:hourly => ..., :daily => ...)`
    - Each frequency key contains component results: `Dict(:component => Dict(:field => Array))`
  - `accessors`: Nested dictionary matching results structure
    - Each frequency key contains component accessors: `Dict(:component => Dict(:field => Function))`

# Component Frequency Assignment
Components are assigned to frequency groups based on their type-level `storage_frequency` trait:
- Components with `HourlyStorage()` → stored in `results[:hourly]`
- Components with `DailyStorage()` → stored in `results[:daily]`
- Components with `NoStorage()` → not included in results

# Array Sizing
- Hourly arrays: size = `n_timesteps`
- Daily arrays: size = `div(n_timesteps, 24, RoundUp) + 2`

# Examples
```julia
# Define storage frequencies for components
storage_frequency(::Type{HydrologicState}) = HourlyStorage()
storage_frequency(::Type{VegetationState}) = DailyStorage()
storage_frequency(::Type{AuxiliaryVariables}) = NoStorage()

# Prepare grouped results
results, accessors = prepare_results(StateVariableSet, AllOutputs, model, 720)

# Access hourly data (720 timesteps)
results[:hourly][:hydrologic][:water]  # Size: (720,)

# Access daily data (30 days + 2 buffer = 32)
results[:daily][:vegetation][:lai]     # Size: (32,)

# Components with NoStorage() are not present in results
!haskey(results[:hourly], :auxiliary) && !haskey(results[:daily], :auxiliary)
```

# Usage with assign_results!
```julia
results, accs = prepare_results(StateVariableSet, AllOutputs, model, 720)

day_counter = 0
for t in 1:720
    # ... model step ...

    # Track day changes (user responsibility)
    if hour(model.forcing) == 1
        day_counter += 1
    end

    # Assign values at appropriate frequencies
    assign_results!(results, accs, model, t, day_counter)
end
```

# See Also
- [`assign_results!`](@ref): Assign values to frequency-grouped results
- [`storage_frequency`](@ref): Define component storage frequency
- [`prepare_component_results`](@ref): Frequency-agnostic component preparation
"""
function prepare_results(::Type{T}, ::Type{O}, model, n_timesteps::Int) where {T,O}
    # Create full accessor dictionary
    full_accessors = accessors(T, O)

    # Initialize frequency-grouped dictionaries
    hourly_accessors = Dict{Symbol,Dict{Symbol,Function}}()
    daily_accessors = Dict{Symbol,Dict{Symbol,Function}}()
    static_accessors = Dict{Symbol,Dict{Symbol,Function}}()

    # Group accessors by component frequency
    for (component_key, component_accessors) in full_accessors
        # Get the component from model to determine its type
        component = getproperty(model, component_key)
        component_type = typeof(component)

        # Determine storage frequency for this component
        freq = storage_frequency(component_type)

        # Assign to appropriate frequency group
        if freq isa HourlyStorage
            hourly_accessors[component_key] = component_accessors
        elseif freq isa DailyStorage
            daily_accessors[component_key] = component_accessors
        elseif freq isa StaticStorage
            static_accessors[component_key] = component_accessors
        end
        # NoStorage components are not included
    end

    # Allocate results for each frequency group
    results = Dict{Symbol,Dict{Symbol,Dict{Symbol,Any}}}()
    accessor_groups = Dict{Symbol,Dict{Symbol,Dict{Symbol,Function}}}()

    if !isempty(hourly_accessors)
        results[:hourly] = allocate_results_from_accessors(
            hourly_accessors, model, n_timesteps; frequency=HourlyStorage()
        )
        accessor_groups[:hourly] = hourly_accessors
        # elseif T == ForcingInputSet
        #     # For forcing, always allocate hourly to hold Datam even if no other fields
        #     results[:hourly] = Dict{Symbol,Any}()
        #     accessor_groups[:hourly] = Dict{Symbol,Dict{Symbol,Function}}()
    end

    if !isempty(daily_accessors)
        results[:daily] = allocate_results_from_accessors(
            daily_accessors, model, n_timesteps; frequency=DailyStorage()
        )
        accessor_groups[:daily] = daily_accessors
    end

    if !isempty(static_accessors)
        results[:static] = allocate_static_results_from_accessors(static_accessors, model)
        accessor_groups[:static] = static_accessors
    end

    return results, accessor_groups
end

"""
    assign_component_results!(
        results::Dict{Symbol,Dict{Symbol,Array}},
        accessors::Dict{Symbol,Dict{Symbol,Function}},
        model_component::M,
        timestep::Int,
    ) where {M}

Assign the current model variable values to the results arrays at the specified timestep.

# Arguments
- `results::Dict{Symbol,Dict{Symbol,Array}}`: Nested dictionary of results arrays
- `accessors::Dict{Symbol,Dict{Symbol,Function}}`: Nested dictionary of accessor functions
- `model_component::M`: The model component instance
- `timestep::Int`: The current timestep index
"""
function assign_component_results!(
    results::Dict{Symbol,Dict{Symbol,Any}},
    accessors::Dict{Symbol,Dict{Symbol,Function}},
    model_component::M,
    timestep::Int,
) where {M}
    for (component_field, component_accessors) in accessors
        for (field, accessor) in component_accessors
            _assign_field!(
                results[component_field][field], accessor(model_component), timestep
            )
        end
    end
    return nothing
end

function _assign_field!(field::AbstractVector, field_value::Number, timestep::Signed)
    field[timestep] = field_value
    return nothing
end

function _assign_field!(
    field::AbstractMatrix, field_value::AbstractVector, timestep::Signed
)
    field[timestep, :] = field_value
    return nothing
end

function _assign_field!(field::AbstractArray, field_value::AbstractMatrix, timestep::Signed)
    field[timestep, :, :] = field_value
    return nothing
end

"""
    assign_results!(
        results::Dict{Symbol,Dict},
        accessors::Dict{Symbol,Dict},
        model,
        timestep::Int,
        day::Int
    )

Assign model values to frequency-grouped results at appropriate temporal resolutions.

This function handles assignment for results prepared by `prepare_results`, which groups
components by storage frequency. Hourly data is assigned every timestep, while daily data
is only assigned when the day counter is greater than zero.

# Arguments
- `results::Dict{Symbol,Dict}`: Frequency-grouped results from `prepare_results`
  - Structure: `Dict(:hourly => Dict(:component => Dict(:field => Array)), :daily => ...)`
- `accessors::Dict{Symbol,Dict}`: Frequency-grouped accessors from `prepare_results`
  - Same structure as results
- `model`: The model instance containing all components
- `timestep::Int`: Current hourly timestep index (1-based)
- `day::Int`: Current day index (0 = no days completed yet, 1 = first day completed, etc.)

# Assignment Behavior
- **Hourly data** (`:hourly` key): Assigned at every timestep regardless of `day` value
  - Uses `timestep` as the array index
- **Daily data** (`:daily` key): Only assigned when `day > 0`
  - Uses `day` as the array index
  - Skipped when `day == 0` (no complete days yet)

# User Responsibility: Day Tracking
The user is responsible for maintaining the day counter. Typical pattern:
```julia
day_counter = 0
for t in 1:n_timesteps
    # ... run model timestep ...

    # Check if a new day has started (user-defined logic)
    if is_new_day(model)  # e.g., Dates.hour(model.forcing) == 1
        day_counter += 1
    end

    # Assign results
    assign_results!(results, accessors, model, t, day_counter)
end
```

# Examples
```julia
# Prepare frequency-grouped results
results, accs = prepare_results(StateVariableSet, AllOutputs, model, 720)

# Simulation loop with day tracking
day = 0
for t in 1:720
    # Model timestep
    step_model!(model)

    # Track day changes (example: check if hour == 1)
    if Dates.hour(model.forcing) == 1
        day += 1
    end

    # Assign results (hourly every step, daily only when day > 0)
    assign_results!(results, accs, model, t, day)
end

# After loop:
# results[:hourly][:hydrologic][:water] has 720 values (all filled)
# results[:daily][:vegetation][:lai] has 30 values (days 1-30, indices 1-30)
```

# Edge Cases
- `day == 0`: Only hourly data is assigned, daily data is skipped
  - This handles the initial period before the first complete day
- Empty frequency groups: If results doesn't have `:hourly` or `:daily` keys, those are skipped
- Component with NoStorage: Not present in results, automatically skipped

# See Also
- [`prepare_results`](@ref): Prepare frequency-grouped results
- [`assign_component_results!`](@ref): Assign values for single-frequency component results
- [`storage_frequency`](@ref): Define component storage frequency
"""
function assign_results!(
    results::Dict{Symbol,<:Dict},
    accessors::Dict{Symbol,<:Dict},
    model,
    timestep::Int,
    day::Int,
)
    # Assign hourly data (always)
    if haskey(results, :hourly) && haskey(accessors, :hourly)
        # Create a nested dict matching assign_component_results! expectations
        assign_component_results!(results[:hourly], accessors[:hourly], model, timestep)
    end

    # Assign daily data (only when day > 0)
    if day > 0 && haskey(results, :daily) && haskey(accessors, :daily)
        # Create a nested dict matching assign_component_results! expectations
        assign_component_results!(results[:daily], accessors[:daily], model, day)
    end

    return nothing
end
