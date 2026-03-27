
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

This function supports hierarchical output selection where `outputs_to_save` is called
at each level of the type hierarchy to enable fine-grained control over which fields
are included in the output.

# Arguments
- `T::Type{T}`: The model component type
- `O::Type{O}`: The outputs to save type

# Returns
- `Dict{Symbol,Dict{Symbol,Function}}`: Nested dictionary of accessor functions

# Examples
```julia
# Define output selection at each hierarchy level
outputs_to_save(::Type{StateVariableSet}, ::Type{SimpleOutputs}) = (:hydrologic,)
outputs_to_save(::Type{HydrologicStateVariables}, ::Type{SimpleOutputs}) =
    (:scalar_field, :high, :low)
outputs_to_save(::Type{HeightDependentHydrologicStateVariables}, ::Type{SimpleOutputs}) =
    (:field1,)

# Create accessors
acc = accessors(StateVariableSet, SimpleOutputs)
# Returns: Dict(:hydrologic => Dict(:scalar_field => fn, :field1_H => fn, :field1_L => fn))
```
"""
function accessors(::Type{T}, ::Type{O}) where {T,O}
    fns = outputs_to_save(T, O)

    base = accessors(T, decrease(O))
    if isa(fns, Symbol) || !isempty(fns)
        merge!(base, create_accessor_dict(T, O, fns; parent_accessor=parent_accessor(T)))
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
    create_accessor_dict(::Type{T}, ::Type{O}, fns::NTuple) where {T,O}

Create a nested dictionary of accessor functions for type `T` for the specified fields `fns`,
with output selection controlled by output level `O`.

Supports hierarchical output selection through recursive calls to `outputs_to_save`:
- **Two-level nesting**: Components without height structure (no `high`/`low` fields)
  - Returns `Dict(:component => Dict(:field => accessor_fn))`
  - All fields from `fieldnames(component_type)` are included
- **Three-level nesting**: Components with height structure (`high` and `low` fields)
  - Calls `outputs_to_save(component_type, O)` to determine which fields to include
  - If `:high` is in the result, calls `outputs_to_save(high_type, O)` for nested fields
  - If `:low` is in the result, calls `outputs_to_save(low_type, O)` for nested fields
  - Fields within `high` get `_H` suffix, fields within `low` get `_L` suffix
  - Direct fields on the component (not in `high`/`low`) remain unsuffixed
  - **Strict mode**: If `outputs_to_save` returns `()` for any type, no accessors created

# Arguments
- `T::Type{T}`: The model component type
- `O::Type{O}`: The outputs to save type
- `fns::NTuple`: The fields to create accessors for (from parent level's `outputs_to_save`)
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

outputs_to_save(::Type{ParamSet}, ::Type{AllOutputs}) = (:soil,)

acc = create_accessor_dict(ParamSet{Float64}, AllOutputs, (:soil,))
# Returns: Dict(:soil => Dict(:Osat => fn, :Ohy => fn))

# Three-level structure with hierarchical selection
struct HeightDepVars{FT}
    field1::FT
    field2::FT
    field3::FT
end

struct HydroVars{FT}
    scalar::FT
    high::HeightDepVars{FT}
    low::HeightDepVars{FT}
end

struct VarSet{FT}
    hydro::HydroVars{FT}
end

# Define selection at each level
outputs_to_save(::Type{VarSet}, ::Type{SimpleOutputs}) = (:hydro,)
outputs_to_save(::Type{HydroVars}, ::Type{SimpleOutputs}) = (:scalar, :high, :low)
outputs_to_save(::Type{HeightDepVars}, ::Type{SimpleOutputs}) = (:field1,)

acc = create_accessor_dict(VarSet{Float64}, SimpleOutputs, (:hydro,))
# Returns: Dict(:hydro => Dict(:scalar => fn, :field1_H => fn, :field1_L => fn))
```
"""
function create_accessor_dict(
    ::Type{T}, ::Type{O}, fns::NTuple; parent_accessor::Function=identity
) where {T,O<:AbstractOutputsToSave}
    result = Dict{Symbol,Dict{Symbol,Function}}()

    for fn in fns
        component_type = fieldtype(T, fn)

        # Check if component has height-dependent structure (high/low fields)
        if is_height_dependent(component_type)
            # Three-level nesting: query which fields from this component to include
            component_fields_to_save = outputs_to_save(component_type, O)

            # STRICT MODE: If empty, create no accessors for this component
            if isempty(component_fields_to_save)
                continue
            end

            # Check which height layers to include
            include_high = :high in component_fields_to_save
            include_low = :low in component_fields_to_save

            inner_dict = Dict{Symbol,Function}()

            # Process high layer
            # Combine as one step to avoid redundant calls to outputs_to_save if both high and low are included
            if include_high
                high_type = fieldtype(component_type, :high)
                high_fields_to_save = outputs_to_save(high_type, O)

                # STRICT MODE: If high selected but no fields specified, skip
                if !isempty(high_fields_to_save)
                    for sub_fn in high_fields_to_save
                        suffixed_key = Symbol(string(sub_fn) * "_H")
                        inner_dict[suffixed_key] =
                            x -> getfield(
                                getfield(getfield(parent_accessor(x), fn), :high),
                                sub_fn,
                            )
                    end
                end
            end

            # Process low layer
            if include_low
                low_type = fieldtype(component_type, :low)
                low_fields_to_save = outputs_to_save(low_type, O)

                # STRICT MODE: If low selected but no fields specified, skip
                if !isempty(low_fields_to_save)
                    for sub_fn in low_fields_to_save
                        suffixed_key = Symbol(string(sub_fn) * "_L")
                        inner_dict[suffixed_key] =
                            x -> getfield(
                                getfield(getfield(parent_accessor(x), fn), :low), sub_fn
                            )
                    end
                end
            end

            # Add direct fields (not in high/low)
            for direct_fn in component_fields_to_save
                if direct_fn != :high && direct_fn != :low
                    inner_dict[direct_fn] =
                        x -> getfield(getfield(parent_accessor(x), fn), direct_fn)
                end
            end

            # Only add to result if we created any accessors
            if !isempty(inner_dict)
                result[fn] = inner_dict
            end
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
