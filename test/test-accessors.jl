using Test
using TethysChlorisCore
using TethysChlorisCore: accessors, AllOutputs, NoOutputs
using TethysChlorisCore: TethysChlorisCore

struct NestedSubComponent
    subfield1::Float64
    subfield2::Float64
end

struct NestedComponent1
    field1::Float64
    subnested1::Float64
end

struct NestedComponent2
    field3::Float64
    field4::Float64
end

struct TopComponent{FT<:AbstractFloat} <: AbstractModelComponent{FT}
    nested1::NestedComponent1
    nested2::NestedComponent2
end

TethysChlorisCore.decrease(::Type{AllOutputs}) = NoOutputs

function TethysChlorisCore.outputs_to_save(::Type{T}, ::Type{AllOutputs}) where {T}
    return fieldnames(T)
end

accessors(TopComponent, AllOutputs) # is a Dict{Symbol, Dict{Symbol, Function}}()
