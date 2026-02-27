
"""
    get_parent_accessor(::Type{T}) where {T}

Get a function that navigates from a top-level model object to the parent of component `T`.
Defaults to `identity`.
"""
function parent_accessor(::Type{T}) where {T}
    return identity
end

"""
    accessors(T::Type{T}, O::Type{O}) where {T,O}

Create a nested dictionary of accessor functions for type `T` corresponding to the outputs
to save defined by type `O`. The function is recursive, building the dictionary from the
bottom up by decreasing the output type until reaching `NoOutputs`.

# Arguments
- `T::Type{T}`: The model component type
- `O::Type{O}`: The outputs to save type

# Returns
- `Dict{Symbol,Dict{Symbol,Function}}`: Nested dictionary of accessor functions
"""
function accessors(::Type{T}, ::Type{O}) where {T,O}
    fns = outputs_to_save(T, O)

    base = accessors(T, decrease(O))
    if isa(fns, Symbol) || !isempty(fns)
        merge!(base, create_accessor_dict(T, fns; parent_accessor=parent_accessor(T)))
    end
    return base
end

function accessors(::Type{T}, ::Type{NoOutputs}) where {T}
    return Dict{Symbol,Dict{Symbol,Function}}()
end

"""
    create_accessor_dict(::Type{T}, fns::NTuple=fieldnames(T)) where {T}

Create a nested dictionary of accessor functions for type `T` for the specified fields `fns`.

# Arguments
- `T::Type{T}`: The model component type
- `fns::NTuple`: The fields to create accessors for (default: all fields of `T`)
- `parent_accessor::Function`: A function that takes a model instance and returns the parent of the component (default: `identity`)

# Returns
- `Dict{Symbol,Dict{Symbol,Function}}`: Nested dictionary of accessor functions
"""
function create_accessor_dict(
    ::Type{T}, fns::NTuple=fieldnames(T); parent_accessor::Function=identity
) where {T}
    return Dict{Symbol,Dict{Symbol,Function}}(
        fn => Dict{Symbol,Function}(
            sub_fn => (x -> getfield(getfield(parent_accessor(x), fn), sub_fn)) for
            sub_fn in fieldnames(fieldtype(T, fn))
        ) for fn in fns
    )
end
