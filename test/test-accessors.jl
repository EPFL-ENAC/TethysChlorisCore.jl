using Test
using TethysChlorisCore
using TethysChlorisCore: accessors, AllOutputs, NoOutputs
using TethysChlorisCore: TethysChlorisCore, is_height_dependent

# ============================================================================
# Test types for two-level nesting (backward compatibility)
# ============================================================================

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

# ============================================================================
# Test types for three-level nesting with height dependency
# ============================================================================

# Height-dependent parameters (Level 3)
Base.@kwdef struct HeightDependentVegetationParameters{FT<:AbstractFloat}
    Knit::FT  # Canopy nitrogen decay coefficient
    FI::FT    # Intrinsic quantum efficiency
end

# Vegetation parameters with high/low structure (Level 2)
Base.@kwdef struct VegetationParameters{FT<:AbstractFloat}
    high::HeightDependentVegetationParameters{FT}
    low::HeightDependentVegetationParameters{FT}
    KcI::FT  # Interception drainage rate coefficient (no height dependency)
end

# Soil parameters without height dependency (Level 2)
Base.@kwdef struct SoilParameters{FT<:AbstractFloat}
    Osat::FT  # Saturation moisture
    Ohy::FT   # Hygroscopic moisture
end

# Top-level parameter set mixing both types (Level 1)
Base.@kwdef struct ParameterSet{FT<:AbstractFloat} <: AbstractModelComponent{FT}
    soil::SoilParameters{FT}
    vegetation::VegetationParameters{FT}
end

# ============================================================================
# Test types for asymmetric high/low fields
# ============================================================================

Base.@kwdef struct AsymmetricHighParams{FT<:AbstractFloat}
    field_a::FT
    field_b::FT
end

Base.@kwdef struct AsymmetricLowParams{FT<:AbstractFloat}
    field_a::FT
    field_c::FT  # Different field than high
end

Base.@kwdef struct AsymmetricVegetationParams{FT<:AbstractFloat}
    high::AsymmetricHighParams{FT}
    low::AsymmetricLowParams{FT}
end

Base.@kwdef struct AsymmetricParamSet{FT<:AbstractFloat} <: AbstractModelComponent{FT}
    vegetation::AsymmetricVegetationParams{FT}
end

# ============================================================================
# Test types for error cases
# ============================================================================

Base.@kwdef struct OnlyHighParams{FT<:AbstractFloat}
    value::FT
end

Base.@kwdef struct InvalidParams{FT<:AbstractFloat}
    high::OnlyHighParams{FT}
    # Missing 'low' field - should throw error
end

Base.@kwdef struct InvalidParams2{FT<:AbstractFloat}
    low::OnlyHighParams{FT}
    # Missing 'high' field - should throw error
end

# Wrapper types to test error detection
Base.@kwdef struct InvalidParamSet{FT<:AbstractFloat} <: AbstractModelComponent{FT}
    params::InvalidParams{FT}
end

Base.@kwdef struct InvalidParamSet2{FT<:AbstractFloat} <: AbstractModelComponent{FT}
    params::InvalidParams2{FT}
end

# ============================================================================
# Output level definitions
# ============================================================================

TethysChlorisCore.decrease(::Type{AllOutputs}) = NoOutputs

function TethysChlorisCore.outputs_to_save(::Type{T}, ::Type{AllOutputs}) where {T}
    return fieldnames(T)
end

# ============================================================================
# Tests
# ============================================================================

@testset "Backward compatibility - two-level accessors" begin
    # Test that existing two-level structures work unchanged
    acc = accessors(TopComponent{Float64}, AllOutputs)

    @test isa(acc, Dict{Symbol,Dict{Symbol,Function}})
    @test haskey(acc, :nested1)
    @test haskey(acc, :nested2)

    # Verify nested1 fields
    @test haskey(acc[:nested1], :field1)
    @test haskey(acc[:nested1], :subnested1)
    @test !haskey(acc[:nested1], :field1_H)
    @test !haskey(acc[:nested1], :field1_L)

    # Verify nested2 fields
    @test haskey(acc[:nested2], :field3)
    @test haskey(acc[:nested2], :field4)

    # Test accessor functions work correctly
    model = TopComponent{Float64}(NestedComponent1(1.0, 2.0), NestedComponent2(3.0, 4.0))

    @test acc[:nested1][:field1](model) == 1.0
    @test acc[:nested1][:subnested1](model) == 2.0
    @test acc[:nested2][:field3](model) == 3.0
    @test acc[:nested2][:field4](model) == 4.0
end

@testset "Three-level height-dependent accessors" begin
    acc = accessors(ParameterSet{Float64}, AllOutputs)

    # Verify structure
    @test isa(acc, Dict{Symbol,Dict{Symbol,Function}})
    @test haskey(acc, :vegetation)
    @test haskey(acc, :soil)

    # Verify vegetation has height-suffixed keys
    @test haskey(acc[:vegetation], :Knit_H)
    @test haskey(acc[:vegetation], :Knit_L)
    @test haskey(acc[:vegetation], :FI_H)
    @test haskey(acc[:vegetation], :FI_L)
    @test haskey(acc[:vegetation], :KcI)  # Direct field, no suffix

    # Verify no non-suffixed height-dependent fields
    @test !haskey(acc[:vegetation], :Knit)
    @test !haskey(acc[:vegetation], :FI)
    @test !haskey(acc[:vegetation], :high)
    @test !haskey(acc[:vegetation], :low)

    # Verify soil has no height suffixes
    @test haskey(acc[:soil], :Osat)
    @test haskey(acc[:soil], :Ohy)
    @test !haskey(acc[:soil], :Osat_H)
    @test !haskey(acc[:soil], :Osat_L)

    # Test accessor functions work correctly
    params = ParameterSet(
        soil=SoilParameters(Osat=0.5, Ohy=0.1),
        vegetation=VegetationParameters(
            high=HeightDependentVegetationParameters(Knit=1.0, FI=2.0),
            low=HeightDependentVegetationParameters(Knit=3.0, FI=4.0),
            KcI=5.0,
        ),
    )

    @test acc[:vegetation][:Knit_H](params) == 1.0
    @test acc[:vegetation][:Knit_L](params) == 3.0
    @test acc[:vegetation][:FI_H](params) == 2.0
    @test acc[:vegetation][:FI_L](params) == 4.0
    @test acc[:vegetation][:KcI](params) == 5.0
    @test acc[:soil][:Osat](params) == 0.5
    @test acc[:soil][:Ohy](params) == 0.1
end

@testset "Asymmetric high/low fields" begin
    # Should silently handle differences - create only fields that exist in each
    acc = accessors(AsymmetricParamSet{Float64}, AllOutputs)

    @test haskey(acc, :vegetation)

    # Both high and low have field_a
    @test haskey(acc[:vegetation], :field_a_H)
    @test haskey(acc[:vegetation], :field_a_L)

    # Only high has field_b
    @test haskey(acc[:vegetation], :field_b_H)
    @test !haskey(acc[:vegetation], :field_b_L)

    # Only low has field_c
    @test !haskey(acc[:vegetation], :field_c_H)
    @test haskey(acc[:vegetation], :field_c_L)

    # Test accessor functions
    params = AsymmetricParamSet(
        vegetation=AsymmetricVegetationParams(
            high=AsymmetricHighParams(field_a=1.0, field_b=2.0),
            low=AsymmetricLowParams(field_a=3.0, field_c=4.0),
        ),
    )

    @test acc[:vegetation][:field_a_H](params) == 1.0
    @test acc[:vegetation][:field_a_L](params) == 3.0
    @test acc[:vegetation][:field_b_H](params) == 2.0
    @test acc[:vegetation][:field_c_L](params) == 4.0
end

@testset "is_height_dependent function" begin
    # Types with both high and low
    @test is_height_dependent(VegetationParameters{Float64})
    @test is_height_dependent(AsymmetricVegetationParams{Float64})

    # Types without high/low
    @test !is_height_dependent(SoilParameters{Float64})
    @test !is_height_dependent(NestedComponent1)

    # Types with only high (should throw error)
    @test_throws ArgumentError is_height_dependent(InvalidParams{Float64})

    # Types with only low (should throw error)
    @test_throws ArgumentError is_height_dependent(InvalidParams2{Float64})
end

@testset "Error handling for asymmetric high/low" begin
    # Creating accessors should fail when component has only high or only low
    @test_throws ArgumentError accessors(InvalidParamSet{Float64}, AllOutputs)  # Only has :high
    @test_throws ArgumentError accessors(InvalidParamSet2{Float64}, AllOutputs)  # Only has :low
end
