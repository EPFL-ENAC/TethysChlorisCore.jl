
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
    is_height_dependent(::Type{T}) where {T}

Check if type `T` has a height-dependent structure (contains both `high` and `low` fields).

# Arguments
- `T::Type{T}`: The type to check

# Returns
- `Bool`: `true` if the type contains both `:high` and `:low` fields, `false` otherwise

# Throws
- `ArgumentError`: If the type contains only one of `:high` or `:low` (asymmetric structure)
"""
function is_height_dependent(::Type{T}) where {T}
    fnames = fieldnames(T)
    has_high = :high in fnames
    has_low = :low in fnames

    # Error if asymmetric (only high OR only low)
    if has_high ⊻ has_low  # XOR: true if exactly one is true
        throw(
            ArgumentError(
                "Type $T has asymmetric height structure: contains " *
                "$(has_high ? ":high" : ":low") but not $(has_high ? ":low" : ":high")",
            ),
        )
    end

    return has_high && has_low
end

"""
    create_accessor_dict(::Type{T}, fns::NTuple=fieldnames(T)) where {T}

Create a nested dictionary of accessor functions for type `T` for the specified fields `fns`.

Supports both two-level and three-level nesting:
- **Two-level nesting**: Components without height structure (no `high`/`low` fields)
  - Returns `Dict(:component => Dict(:field => accessor_fn))`
- **Three-level nesting**: Components with height structure (`high` and `low` fields)
  - Returns `Dict(:component => Dict(:field_H => accessor_fn_high, :field_L => accessor_fn_low))`
  - Fields within `high` get `_H` suffix, fields within `low` get `_L` suffix
  - Direct fields on the component (not in `high`/`low`) remain unsuffixed

# Arguments
- `T::Type{T}`: The model component type
- `fns::NTuple`: The fields to create accessors for (default: all fields of `T`)
- `parent_accessor::Function`: A function that takes a model instance and returns the parent of the component (default: `identity`)

# Returns
- `Dict{Symbol,Dict{Symbol,Function}}`: Nested dictionary of accessor functions

# Examples
```julia
# Two-level structure (no height dependency)
struct SoilParams{FT}
    Osat::FT
    Ohy::FT
end

struct ParamSet{FT}
    soil::SoilParams{FT}
end

acc = create_accessor_dict(ParamSet{Float64})
# Returns: Dict(:soil => Dict(:Osat => fn, :Ohy => fn))

# Three-level structure (with height dependency)
struct HeightDepParams{FT}
    Knit::FT
    FI::FT
end

struct VegParams{FT}
    high::HeightDepParams{FT}
    low::HeightDepParams{FT}
    KcI::FT  # Direct field, no suffix
end

struct ParamSet2{FT}
    vegetation::VegParams{FT}
end

acc = create_accessor_dict(ParamSet2{Float64})
# Returns: Dict(:vegetation => Dict(:Knit_H => fn, :Knit_L => fn, :FI_H => fn, :FI_L => fn, :KcI => fn))
```
"""
function create_accessor_dict(
    ::Type{T}, fns::NTuple=fieldnames(T); parent_accessor::Function=identity
) where {T}
    result = Dict{Symbol,Dict{Symbol,Function}}()

    for fn in fns
        component_type = fieldtype(T, fn)

        # Check if component has height-dependent structure (high/low fields)
        if is_height_dependent(component_type)
            # Three-level nesting: expand with _H and _L suffixes
            high_type = fieldtype(component_type, :high)
            low_type = fieldtype(component_type, :low)

            inner_dict = Dict{Symbol,Function}()

            # Add _H suffixed accessors for high canopy
            for sub_fn in fieldnames(high_type)
                suffixed_key = Symbol(string(sub_fn) * "_H")
                inner_dict[suffixed_key] =
                    x -> getfield(getfield(getfield(parent_accessor(x), fn), :high), sub_fn)
            end

            # Add _L suffixed accessors for low canopy
            for sub_fn in fieldnames(low_type)
                suffixed_key = Symbol(string(sub_fn) * "_L")
                inner_dict[suffixed_key] =
                    x -> getfield(getfield(getfield(parent_accessor(x), fn), :low), sub_fn)
            end

            # Add direct fields (not in high/low) without suffix
            component_fields = fieldnames(component_type)
            for direct_fn in component_fields
                if direct_fn != :high && direct_fn != :low
                    inner_dict[direct_fn] =
                        x -> getfield(getfield(parent_accessor(x), fn), direct_fn)
                end
            end

            result[fn] = inner_dict
        else
            # Two-level nesting: use existing logic (backward compatible)
            result[fn] = Dict{Symbol,Function}(
                sub_fn => (x -> getfield(getfield(parent_accessor(x), fn), sub_fn)) for
                sub_fn in fieldnames(component_type)
            )
        end
    end

    return result
end
