using Test
using TethysChlorisCore
using NCDatasets

# Create test component types
Base.@kwdef struct TestParams{FT<:AbstractFloat} <: AbstractParameters{FT}
    required::FT
    optional::FT
end

Base.@kwdef struct TestAuxVars{FT<:AbstractFloat} <: AbstractAuxiliaryVariables{FT}
    var1::Array{FT,2}
    var2::Array{FT,3}
end

# Test implementations
function TethysChlorisCore.get_required_fields(::Type{TestParams})
    return [:required]
end

function TethysChlorisCore.get_dimensions(::Type{TestAuxVars}, data)
    return Dict("var1" => (10, 5), "var2" => (10, 5, 3))
end

@testset "Initialize Tests" begin
    @testset "initialize" begin
        # Test successful initialization
        data = Dict("required" => 1.0, "optional" => 2.0)
        comp = initialize(Float64, TestParams, data)
        @test comp.required == 1.0
        @test comp.optional == 2.0

        # Test missing required field
        @test_throws ArgumentError initialize(Float64, TestParams, Dict("optional" => 2.0))

        # Test type mismatch
        @test_throws ArgumentError initialize(
            Float64, TestParams, Dict("required" => "wrong", "optional" => 2.0)
        )
    end

    @testset "get_required_fields" begin
        @test get_required_fields(TestParams) == [:required]
        @test get_required_fields(TestAuxVars) == Symbol[]
    end

    @testset "validate_fields" begin
        @test validate_fields(TestParams, Dict()) === nothing
    end

    @testset "preprocess_fields" begin
        # Test default preprocessing
        data = Dict("test" => 1.0)
        @test preprocess_fields(Float64, TestParams, data) === data

        # Test auxiliary variables preprocessing
        mktempdir() do path
            filename = joinpath(path, "test.nc")
            ds = NCDataset(filename, "c")
            processed = preprocess_fields(Float64, TestAuxVars, ds)
            @test haskey(processed, "var1")
            @test haskey(processed, "var2")
            @test size(processed["var1"]) == (10, 5)
            @test size(processed["var2"]) == (10, 5, 3)
            return close(ds)
        end
    end

    @testset "initialize_field" begin
        mktempdir() do path
            filename = joinpath(path, "test.nc")
            ds = NCDataset(filename, "c")

            # Test initialization with default
            field = initialize_field(Float64, ds, "nonexistent", (2, 3); default=1.0)
            @test size(field) == (2, 3)
            @test all(field[1, :] .== 1.0)

            # Test initialization without default
            field = initialize_field(Float64, ds, "nonexistent", (2, 3))
            @test size(field) == (2, 3)
            @test all(field .== 0.0)

            return close(ds)
        end
    end

    @testset "get_dimensions" begin
        @test isempty(get_dimensions(TestParams, nothing))
        dims = get_dimensions(TestAuxVars, nothing)
        @test dims["var1"] == (10, 5)
        @test dims["var2"] == (10, 5, 3)
    end
end
