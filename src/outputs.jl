abstract type AbstractOutputsToSave end

struct NoOutputs <: AbstractOutputsToSave end
struct AllOutputs <: AbstractOutputsToSave end
const no_outputs = NoOutputs()

function decrease(::Type{T}) where {T<:AbstractOutputsToSave}
    throw(ArgumentError("No method defined for decrease with type $(T)"))
end

"""
    outputs_to_save(::Type{T}, ::Type{O}) where {T, O <: AbstractOutputsToSave}

Get the outputs to save for type `T` corresponding to the outputs to save defined by type
`AbstractOutputsToSave`. By default, returns an empty tuple. This function is expected to be
overloaded for specific types.

# Arguments
- `T::Type{T}`: The model component type
- `::Type{AbstractOutputsToSave}`: The outputs to save type

# Returns
- `Tuple`: Tuple of output field names
"""
function outputs_to_save(::Type{T}, ::Type{O}) where {T,O<:AbstractOutputsToSave}
    return ()
end

function outputs_to_save(::Type{T}) where {T}
    return fieldnames(T)
end

# """
#     allocate_results(::Type{T}, ::Type{O}, model::AbstractModel{FT}, n_timesteps::Int) where {T,O,FT}

# Allocate arrays for storing simulation results with the same nested structure as the
# accessor dictionary. Each array has a temporal dimension as the first dimension, followed
# by dimensions matching the field type.

# # Arguments
# - `T::Type{T}`: The model component type
# - `O::Type{O}`: The outputs to save type
# - `model::AbstractModel{FT}`: The model instance (used to extract type parameters)
# - `n_timesteps::Int`: Number of timesteps in the simulation

# # Returns
# - `Dict{Symbol,Dict{Symbol,Array}}`: Nested dictionary of pre-allocated arrays
# """
# function allocate_results(
#     ::Type{O}, model::AbstractModel{FT}, n_timesteps::Int
# ) where {O,FT<:AbstractFloat}
#     base = Dict{Symbol,Dict{Symbol,Array}}()
#     for field in fieldnames(ModelVariableSet)
#         component_type = fieldtype(ModelVariableSet, field)
#         component_results = allocate_results(component_type, O, model, n_timesteps)
#         if !isempty(component_results)
#             merge!(base, component_results)
#         end
#     end

#     return base
# end

# function allocate_results(
#     ::Type{T}, ::Type{O}, model::AbstractModel{FT}, n_timesteps::Int
# ) where {T,O,FT<:AbstractFloat}
#     fns = outputs_to_save(T, O)

#     base = allocate_results(T, decrease(O), model, n_timesteps)
#     if !isempty(fns)
#         merge!(base, _allocate_component_results(T, fns, model, n_timesteps))
#     end

#     return base
# end

# function allocate_results(
#     ::Type{T}, ::Type{NoOutputs}, model::AbstractModel{FT}, n_timesteps::Int
# ) where {T,FT<:AbstractFloat}
#     return Dict{Symbol,Dict{Symbol,Array}}()
# end

# function _allocate_component_results(
#     ::Type{T}, fns::NTuple, model::AbstractModel{FT}, n_timesteps::Int
# ) where {T,FT<:AbstractFloat}
#     results = Dict{Symbol,Dict{Symbol,Array}}()
#     parent = parent_accessor(T)
#     parent_instance = parent(model)

#     for component_field in fns
#         component_type = fieldtype(T, component_field)
#         component_instance = getfield(parent_instance, component_field)
#         component_results = Dict{Symbol,Array}()

#         for field in fieldnames(component_type)
#             field_instance = getfield(component_instance, field)
#             component_results[field] = _allocate_field_array(field_instance, n_timesteps)
#         end

#         results[component_field] = component_results
#     end

#     return results
# end

# function _allocate_field_array(field_instance::Number, n_timesteps::Int)
#     return zeros(typeof(field_instance), n_timesteps)
# end

# function _allocate_field_array(field_instance::AbstractVector, n_timesteps::Int)
#     return zeros(eltype(field_instance), n_timesteps, length(field_instance))
# end

# function _allocate_field_array(
#     field_instance::SVector{N,Number}, n_timesteps::Int
# ) where {N}
#     return zeros(eltype(field_instance), n_timesteps, N)
# end

# function _allocate_field_array(
#     field_instance::MVector{N,Number}, n_timesteps::Int
# ) where {N}
#     return zeros(eltype(field_instance), n_timesteps, N)
# end

# # """
# #     assign_results!(
# #         results::Dict{Symbol,Dict{Symbol,Array}},
# #         accessors::Dict{Symbol,Dict{Symbol,Function}},
# #         model::AbstractModel{FT},
# #         timestep::Int,
# #     ) where {FT}

# # Assign the current model variable values to the results arrays at the specified timestep.

# # # Arguments
# # - `results::Dict{Symbol,Dict{Symbol,Array}}`: Nested dictionary of results arrays
# # - `accessors::Dict{Symbol,Dict{Symbol,Function}}`: Nested dictionary of accessor functions
# # - `model::AbstractModel{FT}`: The model instance
# # - `timestep::Int`: The current timestep index
# # """
# # function assign_results!(
# #     results::Dict{Symbol,Dict{Symbol,Array}},
# #     accessors::Dict{Symbol,Dict{Symbol,Function}},
# #     model::AbstractModel{FT},
# #     timestep::Int,
# # ) where {FT<:AbstractFloat}
# #     for (component_field, component_accessors) in accessors
# #         for (field, accessor) in component_accessors
# #             _assign_field!(results[component_field][field], accessor(model), timestep)
# #         end
# #     end
# #     return nothing
# # end

# # function _assign_field!(field::AbstractVector, field_value::Number, timestep::Signed)
# #     field[timestep] = field_value
# #     return nothing
# # end

# # function _assign_field!(
# #     field::AbstractMatrix, field_value::AbstractVector, timestep::Signed
# # )
# #     field[timestep, :] = field_value
# #     return nothing
# # end

# # function prepare_results(
# #     ::Type{O}, model::AbstractModel{FT}, n_timesteps::Int
# # ) where {O,FT<:AbstractFloat}
# #     results = allocate_results(O, model, n_timesteps)
# #     accessors_dict = accessors(ModelVariableSet, O)
# #     return results, accessors_dict
# # end

# # # export prepare_results, assign_results!
