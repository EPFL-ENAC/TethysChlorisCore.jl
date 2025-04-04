"""
    initialize(::Type{FT}, ::Type{T}, data::Dict{String,Any}, args...) where {FT<:AbstractFloat, T<:AbstractModelComponent}

Initialize model components with optional fields. The model component requires a keyword constructor.


# Arguments
- `::Type{FT}`: Floating point precision type (e.g., Float32 or Float64)
- `::Type{T}`: Component type constructor that subclasses AbstractModelComponent
- `data`: Data source (e.g., Dict for Parameters, NCDataset for State/Auxiliary variables)
- `args...`: Additional arguments passed to preprocess_fields

# Returns
- `T{FT}`: Initialized component struct of type T with floating point precision FT
"""
function initialize(
    ::Type{FT}, ::Type{T}, data, args...
) where {FT<:AbstractFloat,T<:AbstractModelComponent}
    required_fields = get_required_fields(T)

    # Validate required fields
    if !isempty(required_fields)
        missing_required = if data isa Dict
            filter(name -> !haskey(data, String(name)), required_fields)
        else # NCDataset
            filter(
                name -> !haskey(data, String(name)) && !haskey(data.dim, String(name)),
                required_fields,
            )
        end

        if !isempty(missing_required)
            throw(ArgumentError("Missing required fields: $missing_required"))
        end
    end

    # Component-specific validation
    validate_fields(T, data)

    # Preprocess fields
    processed_data = preprocess_fields(FT, T, data, args...)

    # Initialize with provided fields only
    dict_kwargs = Dict{Symbol,Any}()
    for (key, value) in processed_data
        field = Symbol(key)
        if field in fieldnames(T)
            field_type = fieldtype(T, field)
            if !isa(value, field_type)
                throw(
                    ArgumentError("Field $field must be $field_type, got $(typeof(value))")
                )
            end
            dict_kwargs[field] = value
        end
    end

    # Create with keyword constructor and additional args
    return T{FT}(; dict_kwargs...)
end

"""
    get_required_fields(::Type{T}) where {T<:AbstractModelComponent}

Returns an empty array of symbols representing required fields for a given AbstractModelComponent type.
This is a default method that can be specialized for specific subtypes that need to define their own required fields.

# Returns
- `Vector{Symbol}`: A vector of symbols with the fields required to initialize the AbstractModelComponent type

"""
function get_required_fields(::Type{T}) where {T<:AbstractModelComponent}
    all_fields = Set(fieldnames(T))
    optional_fields = Set(get_optional_fields(T))
    calculated_fields = Set(get_calculated_fields(T))
    return collect(setdiff(setdiff(all_fields, optional_fields), calculated_fields))
end

"""
    get_optional_fields(::Type{T}) where {T<:AbstractModelComponent}

Get a list of optional fields for a given model component type. Optional fields are those that can be omitted when creating
a model component. By default, returns an empty list. Components should override this method if they have optional fields.

# Arguments
- `T`: Type of model component to get optional fields for

# Returns
- `Vector{Symbol}`: List of optional field names
"""
function get_optional_fields(::Type{T}) where {T<:AbstractModelComponent}
    return Symbol[]
end

"""
    get_calculated_fields(::Type{T}) where {T<:AbstractModelComponent}

Get a list of calculated fields for a given model component type. Calculated fields are those that are computed based on
other fields and should not be provided when creating a model component. By default, returns an empty list. Components
should override this method if they have calculated fields.

# Arguments
- `T`: Type of model component to get calculated fields for

# Returns
- `Vector{Symbol}`: List of calculated field names
"""
function get_calculated_fields(::Type{T}) where {T<:AbstractModelComponent}
    return Symbol[]
end

"""
    validate_fields(::Type{T}) where {T<:AbstractModelComponent}

Performs some checks on the fields passed to initialize the AbstractModelComponent type.

# Returns
- `nothing`: If all fields are valid, the function returns nothing

"""
function validate_fields(
    ::Type{T}, data::Dict{String,Any}
) where {T<:AbstractModelComponent}
    return check_extraneous_fields(T, data)
end

# Default: no preprocessing
"""
    preprocess_fields(::Type{FT}, ::Type{T}, data, args...) where {FT<:AbstractFloat,T<:AbstractModelComponent}

Preprocess fields before the initialization of a given AbstractModelComponent type.

# Arguments
- `FT`: Type parameter for floating point precision
- `T`: Type parameter for model components
- `data`: Input data to be preprocessed
- `args...`: Additional arguments

# Returns
- Returns the input data without modifications

This is a default implementation that passes through the input data unchanged.
Custom preprocessing can be implemented by defining methods for specific types.
"""
function preprocess_fields(
    ::Type{FT}, ::Type{T}, data, args...
) where {FT<:AbstractFloat,T<:AbstractModelComponent}
    return data
end

"""
    preprocess_fields(
        ::Type{FT},
        ::Type{T},
        data::NCDataset
    ) where {FT<:AbstractFloat,T<:AbstractAuxiliaryVariables}

Initialize fields for auxiliary variables based on their dimension specifications.

# Arguments
- `FT`: Float type to use for the fields
- `T`: Type of auxiliary variables
- `data`: NCDataset containing the source data

# Returns
- `Dict{String,Any}`: Dictionary of initialized fields
"""
function preprocess_fields(
    ::Type{FT}, ::Type{T}, data::NCDataset
) where {FT<:AbstractFloat,T<:AbstractAuxiliaryVariables}
    processed = Dict{String,Any}()

    dimensions = get_dimensions(T, data)

    for (var, dims) in dimensions
        processed[var] = zeros(FT, dims)
    end

    return processed
end

"""
    initialize_field(
        ::Type{FT},
        data::NCDataset,
        name::String,
        dims::Tuple;
        default::Union{Nothing,Number} = nothing
    ) where {FT<:AbstractFloat}

Initialize a field array with specified dimensions and optionally set initial conditions.

# Arguments
- `FT`: Float type to use for the field array (e.g., Float32, Float64)
- `data`: NCDataset containing source data
- `name`: Name of the variable in the dataset
- `dims`: Tuple specifying the dimensions of the field array
- `default`: Optional default value to use if no initial condition is found

# Returns
- Array{FT}: Initialized array with the specified dimensions, filled with initial conditions if available
"""
function initialize_field(
    ::Type{FT},
    data::NCDataset,
    name::String,
    dims::Tuple;
    default::Union{Nothing,Number}=nothing,
) where {FT<:AbstractFloat}
    arr = zeros(FT, dims)

    # Set initial condition if available
    if haskey(data, name)
        ic = FT.(Array(data[name]))
        # First dimension is time, rest are data dimensions
        idx = (1, fill(:, length(dims) - 1)...)
        arr[idx...] = ic
    elseif !isnothing(default)
        idx = (1, fill(:, length(dims) - 1)...)
        if default isa Number
            arr[idx...] .= default
        else
            arr[idx...] = default
        end
    end

    return arr
end

# Default: no dimensions are provided
"""
    get_dimensions(::Type{T}, data) where {T<:AbstractModelComponent}

Return a dictionary of dimension specifications for a given model component type.
By default returns an empty dictionary. This method should be overridden by concrete types
to specify their required dimensions.

# Arguments
- `T`: Type of the model component
- `data`: Data source containing dimension information

# Returns
- `Dict`: Dictionary mapping variable names to their dimension specifications
"""
function get_dimensions(::Type{T}, data) where {T<:AbstractModelComponent}
    return Dict()
end
