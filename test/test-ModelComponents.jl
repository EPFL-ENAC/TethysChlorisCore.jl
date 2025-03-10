# filepath: test/test_ModelComponents.jl
using Test
using TethysChlorisCore.ModelComponents

@testset "ModelComponents" begin
    @testset "Type hierarchy" begin
        # Test the core type hierarchy
        @test AbstractIndividualModelComponent <: AbstractModelComponent
        @test AbstractHeightDependentModelComponent <: AbstractIndividualModelComponent
        @test AbstractModelComponentSet <: AbstractModelComponent

        # Test auxiliary variables hierarchy
        @test AbstractAuxiliaryVariables <: AbstractIndividualModelComponent
        @test AbstractHeightDependentAuxiliaryVariables <:
              AbstractHeightDependentModelComponent
        @test AbstractAuxiliaryVariableSet <: AbstractModelComponentSet

        # Test forcing inputs hierarchy
        @test AbstractForcingInputs <: AbstractIndividualModelComponent
        @test AbstractHeightDependentForcingInputs <: AbstractHeightDependentModelComponent
        @test AbstractForcingInputSet <: AbstractModelComponentSet

        # Test parameters hierarchy
        @test AbstractParameters <: AbstractIndividualModelComponent
        @test AbstractHeightDependentParameters <: AbstractHeightDependentModelComponent
        @test AbstractParameterSet <: AbstractModelComponentSet

        # Test state variables hierarchy
        @test AbstractStateVariables <: AbstractIndividualModelComponent
        @test AbstractHeightDependentStateVariables <: AbstractHeightDependentModelComponent
        @test AbstractStateVariableSet <: AbstractModelComponentSet
    end

    @testset "Type aliases" begin
        @test AMC === AbstractModelComponent
        @test AIMC === AbstractIndividualModelComponent
        @test AHDMC === AbstractHeightDependentModelComponent
        @test AMCS === AbstractModelComponentSet
    end

    @testset "Parametric type behavior" begin
        # Define concrete subtypes for testing
        struct ConcreteModelComponent{FT<:AbstractFloat} <: AbstractModelComponent{FT}
            value::FT
        end

        struct ConcreteHeightDependentComponent{FT<:AbstractFloat} <:
               AbstractHeightDependentModelComponent{FT}
            values::Vector{FT}
            heights::Vector{FT}
        end

        # Test with different float types
        @test ConcreteModelComponent(1.0f0) isa AbstractModelComponent{Float32}
        @test ConcreteModelComponent(1.0) isa AbstractModelComponent{Float64}

        @test ConcreteHeightDependentComponent([1.0f0], [0.0f0]) isa
              AbstractHeightDependentModelComponent{Float32}
        @test ConcreteHeightDependentComponent([1.0], [0.0]) isa
              AbstractHeightDependentModelComponent{Float64}
    end

    @testset "eltype function" begin
        struct TestComponent{FT<:AbstractFloat} <: AbstractModelComponent{FT}
            value::FT
        end

        # Test eltype for different float types
        @test eltype(TestComponent(1.0f0)) === Float32
        @test eltype(TestComponent(1.0)) === Float64
        @test eltype(TestComponent(BigFloat(1.0))) === BigFloat
    end
end
