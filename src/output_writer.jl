"""
    VariableSpec

Specification of a single output variable streamed by the writers built on this module.

# Fields
- `name::Symbol`: NetCDF variable name
- `group::Symbol`: component/subsystem of the source (e.g. `:hydrologic`, `:meteorological`)
- `source::Symbol`: top-level source set (e.g. `:state`, `:auxiliary`, `:forcing`,
  `:parameters`, `:derived`)
- `dims::Vector{Symbol}`: trailing dimensions of the saved values, left empty by the spec
  enumeration and filled from the extracted shapes
- `acc_op::Symbol`: `:mean` | `:sum` accumulation of time-average-style groups
- `extractor::Function`: `x -> raw field value` for a component-set instance `x`
"""
mutable struct VariableSpec
    name::Symbol
    group::Symbol
    source::Symbol
    dims::Vector{Symbol}
    acc_op::Symbol
    extractor::Function
end

"""
    output_specs(::Type{T}, ::Type{OL}; source = :state) -> Vector{VariableSpec}

Enumerate the [`VariableSpec`](@ref)s that the `outputs_to_save` traits select for the
component set type `T` at output level `OL` (pass the level instance type, e.g.
`AllOutputs`, `NoBiogeochemistryOutputs`).

The traversal is generic over any user-defined set: define `outputs_to_save` for the set
type and its nested components to select which fields to save. Fields of components with
both a `high` and a `low` field receive the `_H`/`_L` suffixes. Components with no
`outputs_to_save` defined for the level are skipped (strict mode). On name collisions
between output levels, the less restrictive level wins (decreasing recursion order).

The returned extractors take a component-set instance and return the raw field value;
the trailing `dims` are left empty for the writer to fill from the shapes. Boolean,
string and other non-numeric leaves are left to the writer to drop.
"""
function output_specs(::Type{T}, ::Type{OL}; source::Symbol=:state) where {T,OL}
    specs = VariableSpec[]
    _append_specs!(specs, T, OL, source)
    return specs
end

function _append_specs!(
    specs::Vector{VariableSpec}, ::Type{T}, ::Type{OL}, source::Symbol
) where {T,OL}
    OL === NoOutputs && return specs
    _append_specs!(specs, T, decrease(OL), source)
    fns = outputs_to_save(T, OL)
    fns = fns isa Symbol ? (fns,) : fns
    for fn in fns
        component_type = fieldtype(T, fn)
        if is_height_dependent(component_type)
            component_fields = outputs_to_save(component_type, OL)
            isempty(component_fields) && continue
            if :high in component_fields
                high_fields = outputs_to_save(fieldtype(component_type, :high), OL)
                _append_specs_height!(
                    specs, fn, :high, "_H", component_type, OL, high_fields, source
                )
            end
            if :low in component_fields
                low_fields = outputs_to_save(fieldtype(component_type, :low), OL)
                _append_specs_height!(
                    specs, fn, :low, "_L", component_type, OL, low_fields, source
                )
            end
            for direct in component_fields
                (direct === :high || direct === :low) && continue
                _upsert_spec!(
                    specs,
                    VariableSpec(
                        direct,
                        fn,
                        source,
                        Symbol[],
                        :mean,
                        x -> getfield(getfield(x, fn), direct),
                    ),
                )
            end
        else
            for sub in fieldnames(component_type)
                _upsert_spec!(
                    specs,
                    VariableSpec(
                        sub,
                        fn,
                        source,
                        Symbol[],
                        :mean,
                        x -> getfield(getfield(x, fn), sub),
                    ),
                )
            end
        end
    end
    return specs
end

function _append_specs_height!(
    specs, fn, height::Symbol, suffix::String, ::Type{T}, ::Type{OL}, fields, source::Symbol
) where {T,OL}
    isempty(fields) && return nothing
    for sub in fields
        _upsert_spec!(
            specs,
            VariableSpec(
                Symbol(string(sub), suffix),
                fn,
                source,
                Symbol[],
                :mean,
                x -> getfield(getfield(getfield(x, fn), height), sub),
            ),
        )
    end
    return nothing
end

function _upsert_spec!(specs::Vector{VariableSpec}, spec::VariableSpec)
    idx = findfirst(s -> (s.name === spec.name && s.group === spec.group), specs)
    if isnothing(idx)
        push!(specs, spec)
    else
        specs[idx] = spec
    end
    return specs
end

function is_height_dependent(::Type{T}) where {T}
    fnames = fieldnames(T)
    has_high = :high in fnames
    has_low = :low in fnames

    # Error if asymmetric (only high OR only low)
    if has_high ⊻ has_low
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
    axis_names(shape; known = (;)) -> Vector{Symbol}

Trailing axis symbols for a value of shape `shape`. `known` is an ordered name-length
named tuple; each axis takes the first unused name whose length matches, otherwise
`axisL`. Names never repeat within one variable. The axes are supplied by the caller
(e.g. model attributes such as layer and crown-area counts), so no axis naming is
hardcoded here.
"""
function axis_names(shape::Tuple; known::NamedTuple=(;))
    out = Symbol[]
    used = Symbol[]
    for L in shape
        name = nothing
        for (n, len) in pairs(known)
            (len == L && !(n in used)) && (name=n; break)
        end
        name === nothing && (name = Symbol(:axis, L))
        push!(used, name)
        push!(out, name)
    end
    return out
end

"""
    chunksizes(dimspecs; time_chunk = 32, naver_chunk = 1) -> Tuple

Chunk sizes for a NetCDF variable whose dimensions are given as ordered `(name, size)`
pairs. Dimensions named `:time` or `:days` (unlimited) get `time_chunk`; dimensions named
`:naver` get `naver_chunk`.
"""
function chunksizes(dimspecs; time_chunk::Int=32, naver_chunk::Int=1)
    sizes = Int[]
    for (name, size) in dimspecs
        push!(
            sizes,
            if name === :naver
                naver_chunk
            elseif (name === :time || name === :days)
                time_chunk
            else
                size
            end,
        )
    end
    return tuple(sizes...)
end

"""
    add_variable!(parent, name, FT, dims; chunksizes, compress, attrib, fillvalue)

Add a NetCDF variable with NaN fill value. Variable-dependent dimensions must exist
beforehand; an unlimited `time` or `naver` dimension switches storage to chunked with the
given `chunksizes`, and `compress` enables deflate level 4.
"""
function add_variable!(
    parent,
    name::Symbol,
    FT,
    dims;
    chunksizes=nothing,
    compress::Bool=false,
    attrib=Dict{String,Any}(),
    fillvalue=FT(NaN),
)
    if isnothing(chunksizes)
        return defVar(
            parent,
            name,
            FT,
            dims;
            attrib=attrib,
            fillvalue=fillvalue,
            deflatelevel=compress ? 4 : nothing,
        )
    end
    return defVar(
        parent,
        name,
        FT,
        dims;
        attrib=attrib,
        fillvalue=fillvalue,
        chunksizes=chunksizes,
        deflatelevel=compress ? 4 : nothing,
    )
end

"""
    TimeBuffers(; buffer_len = 32)

In-memory per-variable step buffers for streamed NetCDF writing. Writing hundreds of
small NetCDF variables at every timestep is prohibitive with the HDF5 backend, so values
are buffered for at most `buffer_len` timesteps and written chunk-wise. The buffer
layout follows the variable: variables whose time-like dimension comes first are shaped
`(buffer_len, dims...)`, variables with a trailing `time`/`naver` dimension are shaped
`(dims..., buffer_len)`.
"""
mutable struct TimeBuffers
    buffers::Dict{Tuple{String,Symbol},Any}
    layouts::Dict{Tuple{String,Symbol},Bool}
    buffer_len::Int
    fill::Int
end

function TimeBuffers(; buffer_len::Int=32)
    TimeBuffers(
        Dict{Tuple{String,Symbol},Any}(), Dict{Tuple{String,Symbol},Bool}(), buffer_len, 0
    )
end

function _buffer_init!(
    tb::TimeBuffers, getvar, key::Tuple{String,Symbol}, ::Type{FT}
) where {FT}
    return get!(tb.buffers, key) do
        var = getvar(key[1], key[2])
        lastn = last(dimnames(var))
        time_last = lastn == "time" || lastn == "naver"
        tb.layouts[key] = time_last
        if time_last
            tails = Tuple(Int(s) for s in size(var)[1:(end - 1)])
            return fill(FT(NaN), (tails..., tb.buffer_len))
        end
        tails = Tuple(Int(s) for s in size(var)[2:end])
        return fill(FT(NaN), (tb.buffer_len, tails...))
    end
end

function _tb_store!(buf, x::Real, ::Val{false}, slot::Int)
    if ndims(buf) == 1
        buf[slot] = x
    else
        buf[slot, :] .= x
    end
    return nothing
end

function _tb_store!(buf, x::AbstractVector, ::Val{false}, slot::Int)
    buf[slot, :] = x
    return nothing
end

function _tb_store!(buf, x::AbstractMatrix, ::Val{false}, slot::Int)
    buf[slot, :, :] = x
    return nothing
end

function _tb_store!(buf, x::Real, ::Val{true}, slot::Int)
    if ndims(buf) == 1
        buf[slot] = x
    else
        buf[:, slot] .= x
    end
    return nothing
end

function _tb_store!(buf, x::AbstractVector, ::Val{true}, slot::Int)
    buf[:, slot] = x
    return nothing
end

function _tb_store!(buf, x::AbstractMatrix, ::Val{true}, slot::Int)
    buf[:, :, slot] = x
    return nothing
end

"""
    store_buffer!(tb, getvar, group, name, x, slot, ::Type{FT})

Store one value for variable `(group, name)` in the buffer at slot `slot`. The variable
handle is fetched through `getvar(group, name)` to determine shape and layout.
"""
function store_buffer!(
    tb::TimeBuffers, getvar, group::String, name::Symbol, x, slot::Int, ::Type{FT}
) where {FT}
    key = (group, name)
    buf = _buffer_init!(tb, getvar, key, FT)
    _tb_store!(buf, x, Val(tb.layouts[key]), slot)
    return nothing
end

"""
    flush_buffers!(tb, getvar, window)

Write all buffered values into their NetCDF variables. `getvar(group, name)` returns the
variable handle; `window` is the timestep range covered by the buffered slots. The buffers
and layouts are kept allocated and reused across flushes; every store overwrites the full
slot, so stale slots are never flushed.
"""
function flush_buffers!(tb::TimeBuffers, getvar, window::UnitRange{Int})
    n = tb.fill
    n == 0 && return nothing
    for (key, buf) in tb.buffers
        var = getvar(key[1], key[2])
        if tb.layouts[key]
            slices = ntuple(_ -> Colon(), ndims(buf) - 1)
            var[slices..., window] = buf[slices..., 1:n]
        else
            slices = ntuple(_ -> Colon(), ndims(buf) - 1)
            var[window, slices...] = buf[1:n, slices...]
        end
    end
    tb.fill = 0
    return nothing
end

"""
    assign_slice!(v, x, tidx)

Assign one value or slice of `x` into variable `v` at index `tidx`, dispatching on the
rank of `x` for variables whose time dimension comes first.
"""
function assign_slice!(v, x::Real, tidx::Int)
    v[tidx] = x
    return nothing
end

function assign_slice!(v, x::AbstractVector, tidx::Int)
    v[tidx, :] = x
    return nothing
end

function assign_slice!(v, x::AbstractMatrix, tidx::Int)
    v[tidx, :, :] = x
    return nothing
end

"""
    assign_average_slice!(var, acc, idx, reshape_dims...)

Reshape the accumulator `acc` to `reshape_dims` and assign it into variable `var` at
index `idx` of its trailing (naver-like) dimension.
"""
function assign_average_slice!(var, acc, idx::Int, reshape_dims::Tuple)
    gridarr = reshape(acc, reshape_dims)
    var[ntuple(_ -> Colon(), ndims(gridarr))..., idx] = gridarr
    return nothing
end

"""
    cell_stats(vals, ::Type{FT}) -> (mean, std)

NaN-aware mean and standard deviation (N−1) of a vector.
"""
function cell_stats(vals, ::Type{FT}) where {FT}
    valid = FT[x for x in vals if !isnan(x)]
    isempty(valid) && return FT(NaN), FT(NaN)
    m = sum(valid) / length(valid)
    s = if length(valid) > 1
        sqrt(sum(abs2, x - m for x in valid) / (length(valid) - 1))
    else
        FT(NaN)
    end
    return m, s
end

"""
    domain_stats(values, ::Type{FT}) -> (means, stds)

NaN-aware means and standard deviations (N−1) of an array reduced over its first
(instance) axis. Scalar inputs return a single pair.
"""
function domain_stats(values::AbstractArray{FT}, ::Type{FT}) where {FT}
    if ndims(values) == 1
        return cell_stats(values, FT)
    end
    tail = size(values)[2:end]
    means = fill(FT(NaN), tail)
    stds = fill(FT(NaN), tail)
    for idx in CartesianIndices(tail)
        col = [values[k, idx] for k in axes(values, 1)]
        means[idx], stds[idx] = cell_stats(col, FT)
    end
    return means, stds
end
