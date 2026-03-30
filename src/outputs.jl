abstract type AbstractOutputsToSave end

struct NoOutputs <: AbstractOutputsToSave end
struct AllOutputs <: AbstractOutputsToSave end
const no_outputs = NoOutputs()

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
        n_timesteps::Int
    ) where {M}

Allocate arrays for storing simulation results based on an existing accessor dictionary.
This ensures perfect key alignment between accessors and result arrays.

This function is used internally by `allocate_results` and can be called directly
from `prepare_results` to avoid creating the accessor dictionary twice.

# Arguments
- `accessors_dict::Dict{Symbol,Dict{Symbol,Function}}`: Accessor dictionary created by `accessors(T, O)`
- `model::M`: The model instance (used to extract field values via accessors)
- `n_timesteps::Int`: Number of timesteps in the simulation

# Returns
- `Dict{Symbol,Dict{Symbol,Array}}`: Nested dictionary of pre-allocated arrays with
  keys exactly matching the accessor dictionary

# Examples
```julia
# Create accessors first
accessor_dict = accessors(StateVariableSet{Float64}, SimpleOutputs)

# Allocate results with matching structure
results = allocate_results_from_accessors(accessor_dict, model, 100)

# Keys are guaranteed to match
@assert keys(results) == keys(accessor_dict)
for component in keys(results)
    @assert keys(results[component]) == keys(accessor_dict[component])
end
```

"""
function allocate_results_from_accessors(
    accessors_dict::Dict{Symbol,Dict{Symbol,Function}}, model::M, n_timesteps::Int
) where {M}
    results = Dict{Symbol,Dict{Symbol,Array}}()

    for (component_field, field_accessors) in accessors_dict
        component_results = Dict{Symbol,Array}()

        for (field_key, accessor_fn) in field_accessors
            # Use the accessor to extract the actual value from the model
            field_value = accessor_fn(model)
            # Allocate array based on the extracted value's type and shape
            component_results[field_key] = _allocate_field_array(field_value, n_timesteps)
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
    prepare_results(::Type{T}, ::Type{O}, model::M, n_timesteps::Int) where {T,O,M}

Prepare both accessor functions and pre-allocated result arrays for a simulation.
This is an optimized convenience function that creates the accessor dictionary once
and reuses it for both access and allocation.

# Arguments
- `T::Type{T}`: The model component type (e.g., `StateVariableSet`)
- `O::Type{O}`: The outputs to save type (e.g., `SimpleOutputs`, `AllOutputs`)
- `model::M`: The model instance
- `n_timesteps::Int`: Number of timesteps in the simulation

# Returns
- `Tuple{Dict{Symbol,Dict{Symbol,Array}}, Dict{Symbol,Dict{Symbol,Function}}}`:
  A tuple of (results, accessors) where:
  - `results`: Pre-allocated arrays for storing values at each timestep
  - `accessors`: Functions for extracting values from the model

# Examples
```julia
# Prepare for simulation
results, accessors_dict = prepare_results(
    StateVariableSet{Float64},
    SimpleOutputs,
    model,
    1000
)

# During simulation, assign values at each timestep
for timestep in 1:1000
    # Update model state...
    assign_results!(results, accessors_dict, model, timestep)
end
```
"""
function prepare_results(::Type{T}, ::Type{O}, model::M, n_timesteps::Int) where {T,O,M}
    accessors_dict = accessors(T, O)
    results = allocate_results_from_accessors(accessors_dict, model, n_timesteps)

    return results, accessors_dict
end
