using Test
using TethysChlorisCore
using TethysChlorisCore: accessors, AllOutputs, NoOutputs, AbstractOutputsToSave
using TethysChlorisCore: TethysChlorisCore, is_height_dependent
using TethysChlorisCore: allocate_results_from_accessors, prepare_component_results

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
# Test types for three-level nesting (old tests - need AllOutputs support)
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
# Test types for fine-grained hierarchical selection
# ============================================================================

Base.@kwdef struct HeightDepVars{FT<:AbstractFloat}
    field1::FT
    field2::FT
    field3::FT
end

Base.@kwdef struct HydroVars{FT<:AbstractFloat}
    scalar::FT
    high::HeightDepVars{FT}
    low::HeightDepVars{FT}
end

Base.@kwdef struct VarSet{FT<:AbstractFloat} <: AbstractModelComponent{FT}
    hydro::HydroVars{FT}
end

struct TestModel{FT,T} <: TethysChlorisCore.AbstractModel
    component_set::T
end
# ============================================================================
# Output level definitions
# ============================================================================

TethysChlorisCore.decrease(::Type{AllOutputs}) = NoOutputs

# AllOutputs for backward compatibility - includes all fields at all levels
function TethysChlorisCore.outputs_to_save(::Type{T}, ::Type{AllOutputs}) where {T}
    return fieldnames(T)
end

# Define output levels for hierarchical selection tests
struct MinimalOutputs <: AbstractOutputsToSave end
struct SimpleOutputs <: AbstractOutputsToSave end
struct ExtendedOutputs <: AbstractOutputsToSave end
struct DirectOnlyOutputs <: AbstractOutputsToSave end
struct HeightOnlyOutputs <: AbstractOutputsToSave end
struct HighOnlyOutputs <: AbstractOutputsToSave end
struct LowOnlyOutputs <: AbstractOutputsToSave end
struct EmptyNestedOutputs <: AbstractOutputsToSave end

# Decrease hierarchy
TethysChlorisCore.decrease(::Type{ExtendedOutputs}) = SimpleOutputs
TethysChlorisCore.decrease(::Type{SimpleOutputs}) = MinimalOutputs
TethysChlorisCore.decrease(::Type{MinimalOutputs}) = NoOutputs
TethysChlorisCore.decrease(::Type{DirectOnlyOutputs}) = NoOutputs
TethysChlorisCore.decrease(::Type{HeightOnlyOutputs}) = NoOutputs
TethysChlorisCore.decrease(::Type{HighOnlyOutputs}) = NoOutputs
TethysChlorisCore.decrease(::Type{LowOnlyOutputs}) = NoOutputs
TethysChlorisCore.decrease(::Type{EmptyNestedOutputs}) = NoOutputs

# MinimalOutputs: only field1 from height-dependent, no scalar
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{MinimalOutputs}
) where {FT}
    (:hydro,)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{MinimalOutputs}
) where {FT}
    (:high, :low)
end  # No scalar field
function TethysChlorisCore.outputs_to_save(
    ::Type{HeightDepVars{FT}}, ::Type{MinimalOutputs}
) where {FT}
    (:field1,)
end

# SimpleOutputs: scalar + field1
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{SimpleOutputs}
) where {FT}
    (:hydro,)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{SimpleOutputs}
) where {FT}
    (:scalar, :high, :low)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HeightDepVars{FT}}, ::Type{SimpleOutputs}
) where {FT}
    (:field1,)
end

# ExtendedOutputs: scalar + field1 + field2
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{ExtendedOutputs}
) where {FT}
    (:hydro,)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{ExtendedOutputs}
) where {FT}
    (:scalar, :high, :low)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HeightDepVars{FT}}, ::Type{ExtendedOutputs}
) where {FT}
    (:field1, :field2)
end

# DirectOnlyOutputs: only scalar, no height fields
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{DirectOnlyOutputs}
) where {FT}
    (:hydro,)
end
function  # No :high or :low
TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{DirectOnlyOutputs}
) where {FT}
    (:scalar,)
end  # No :high or :low

# HeightOnlyOutputs: only height fields, no scalar
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{HeightOnlyOutputs}
) where {FT}
    (:hydro,)
end
function  # No :scalar
TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{HeightOnlyOutputs}
) where {FT}
    (:high, :low)
end  # No :scalar
function TethysChlorisCore.outputs_to_save(
    ::Type{HeightDepVars{FT}}, ::Type{HeightOnlyOutputs}
) where {FT}
    (:field1,)
end

# HighOnlyOutputs: only high layer
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{HighOnlyOutputs}
) where {FT}
    (:hydro,)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{HighOnlyOutputs}
) where {FT}
    (:high,)
end  # Only :high, not :low
function TethysChlorisCore.outputs_to_save(
    ::Type{HeightDepVars{FT}}, ::Type{HighOnlyOutputs}
) where {FT}
    (:field1,)
end

# LowOnlyOutputs: only low layer
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{LowOnlyOutputs}
) where {FT}
    (:hydro,)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{LowOnlyOutputs}
) where {FT}
    (:low,)
end  # Only :low, not :high
function TethysChlorisCore.outputs_to_save(
    ::Type{HeightDepVars{FT}}, ::Type{LowOnlyOutputs}
) where {FT}
    (:field1,)
end

# EmptyNestedOutputs: select :high and :low but return empty tuple for nested type
function TethysChlorisCore.outputs_to_save(
    ::Type{VarSet{FT}}, ::Type{EmptyNestedOutputs}
) where {FT}
    (:hydro,)
end
function TethysChlorisCore.outputs_to_save(
    ::Type{HydroVars{FT}}, ::Type{EmptyNestedOutputs}
) where {FT}
    (:high, :low)
end
# HeightDepVars returns () by default (not overloaded) - tests strict mode

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

@testset "Three-level height-dependent accessors with AllOutputs" begin
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

@testset "Asymmetric high/low fields with AllOutputs" begin
    # Should create accessors for fields that exist in each
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
    @test is_height_dependent(HydroVars{Float64})

    # Types without high/low
    @test !is_height_dependent(SoilParameters{Float64})
    @test !is_height_dependent(NestedComponent1)
    @test !is_height_dependent(HeightDepVars{Float64})

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

@testset "Fine-grained hierarchical output selection" begin
    # Test MinimalOutputs: only field1 from height-dependent, no scalar
    acc_minimal = accessors(VarSet{Float64}, MinimalOutputs)
    @test haskey(acc_minimal, :hydro)
    @test haskey(acc_minimal[:hydro], :field1_H)
    @test haskey(acc_minimal[:hydro], :field1_L)
    @test !haskey(acc_minimal[:hydro], :scalar)  # Not included
    @test !haskey(acc_minimal[:hydro], :field2_H)  # Not included

    # Test SimpleOutputs: scalar + field1
    acc_simple = accessors(VarSet{Float64}, SimpleOutputs)
    @test haskey(acc_simple, :hydro)
    @test haskey(acc_simple[:hydro], :scalar)  # Now included
    @test haskey(acc_simple[:hydro], :field1_H)
    @test haskey(acc_simple[:hydro], :field1_L)
    @test !haskey(acc_simple[:hydro], :field2_H)  # Still not included

    # Test ExtendedOutputs: scalar + field1 + field2
    acc_extended = accessors(VarSet{Float64}, ExtendedOutputs)
    @test haskey(acc_extended, :hydro)
    @test haskey(acc_extended[:hydro], :scalar)
    @test haskey(acc_extended[:hydro], :field1_H)
    @test haskey(acc_extended[:hydro], :field1_L)
    @test haskey(acc_extended[:hydro], :field2_H)  # Now included
    @test haskey(acc_extended[:hydro], :field2_L)  # Now included
    @test !haskey(acc_extended[:hydro], :field3_H)  # Still not included

    # Test accessor functions work correctly
    model = VarSet(
        hydro=HydroVars(
            scalar=10.0,
            high=HeightDepVars(field1=1.0, field2=2.0, field3=3.0),
            low=HeightDepVars(field1=4.0, field2=5.0, field3=6.0),
        ),
    )

    @test acc_simple[:hydro][:scalar](model) == 10.0
    @test acc_simple[:hydro][:field1_H](model) == 1.0
    @test acc_simple[:hydro][:field1_L](model) == 4.0
    @test acc_extended[:hydro][:field2_H](model) == 2.0
    @test acc_extended[:hydro][:field2_L](model) == 5.0
end

@testset "Independent control of direct and height-dependent fields" begin
    # Test DirectOnlyOutputs: only scalar, no height fields
    acc_direct = accessors(VarSet{Float64}, DirectOnlyOutputs)
    @test haskey(acc_direct, :hydro)
    @test haskey(acc_direct[:hydro], :scalar)
    @test !haskey(acc_direct[:hydro], :field1_H)
    @test !haskey(acc_direct[:hydro], :field1_L)

    # Test HeightOnlyOutputs: only height fields, no scalar
    acc_height = accessors(VarSet{Float64}, HeightOnlyOutputs)
    @test haskey(acc_height, :hydro)
    @test !haskey(acc_height[:hydro], :scalar)
    @test haskey(acc_height[:hydro], :field1_H)
    @test haskey(acc_height[:hydro], :field1_L)
end

@testset "Asymmetric height layer selection" begin
    # Test HighOnlyOutputs: only high layer
    acc_high = accessors(VarSet{Float64}, HighOnlyOutputs)
    @test haskey(acc_high, :hydro)
    @test haskey(acc_high[:hydro], :field1_H)
    @test !haskey(acc_high[:hydro], :field1_L)

    # Test LowOnlyOutputs: only low layer
    acc_low = accessors(VarSet{Float64}, LowOnlyOutputs)
    @test haskey(acc_low, :hydro)
    @test !haskey(acc_low[:hydro], :field1_H)
    @test haskey(acc_low[:hydro], :field1_L)
end

@testset "allocate_results_from_accessors Function" begin
    FT = Float64
    n_timesteps = 10

    high_fields = HeightDepVars{FT}(field1=25.0, field2=0.5, field3=101.3)
    low_fields = HeightDepVars{FT}(field1=20.0, field2=0.3, field3=101.0)
    hydro_comp = HydroVars{FT}(scalar=10.0, high=high_fields, low=low_fields)
    component_set = VarSet{FT}(hydro=hydro_comp)
    model = TestModel{FT,VarSet{FT}}(component_set)

    @testset "Direct allocation from accessors" begin
        accessor_dict = accessors(VarSet{FT}, SimpleOutputs)
        results = allocate_results_from_accessors(
            accessor_dict, model.component_set, n_timesteps
        )

        @test results isa Dict{Symbol,Dict{Symbol,Array}}
        @test keys(results) == keys(accessor_dict)
        @test haskey(results, :hydro)
        @test haskey(results[:hydro], :scalar)
        @test haskey(results[:hydro], :field1_H)
        @test haskey(results[:hydro], :field1_L)
    end

    @testset "Returns both results and accessors" begin
        results, accessor_dict = prepare_component_results(
            VarSet{FT}, SimpleOutputs, model.component_set, n_timesteps
        )

        @test results isa Dict{Symbol,Dict{Symbol,Array}}
        @test accessor_dict isa Dict{Symbol,Dict{Symbol,Function}}
        @test keys(results) == keys(accessor_dict)
    end

    @testset "Keys match between results and accessors" begin
        results, accessor_dict = prepare_component_results(
            VarSet{FT}, ExtendedOutputs, model.component_set, n_timesteps
        )

        @test keys(results) == keys(accessor_dict)
        for component in keys(results)
            @test keys(results[component]) == keys(accessor_dict[component])
        end
    end

    @testset "Accessors can extract values matching array types" begin
        results, accessor_dict = prepare_component_results(
            VarSet{FT}, SimpleOutputs, model.component_set, n_timesteps
        )

        for (component, field_accessors) in accessor_dict
            for (field, accessor_fn) in field_accessors
                value = accessor_fn(model.component_set)
                array = results[component][field]

                # Check that the array can hold the value type
                if value isa Number
                    @test size(array, 1) == n_timesteps
                    @test eltype(array) == typeof(value)
                elseif value isa AbstractVector
                    @test size(array, 1) == n_timesteps
                    @test size(array, 2) == length(value)
                    @test eltype(array) == eltype(value)
                end
            end
        end
    end
end
