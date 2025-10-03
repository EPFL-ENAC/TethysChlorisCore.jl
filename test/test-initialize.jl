using Test
using TethysChlorisCore
using NCDatasets

# Create test component types
Base.@kwdef struct TestParams{FT<:AbstractFloat} <: AbstractParameters{FT}
    required::FT
    optional::FT
    calculated::FT
end

function TethysChlorisCore.preprocess_fields(
    ::Type{FT}, ::Type{TestParams}, data::NCDataset, params
) where {FT<:AbstractFloat}
    # Example preprocessing: convert all values to Float64
    processed = Dict{String,Any}()
    processed["required"] = data["required"][]
    if haskey(data, "optional")
        processed["optional"] = data["optional"][]
    else
        processed["optional"] = 0.0  # Default value if optional field is missing
    end
    processed["calculated"] = processed["required"] + processed["optional"]
    return processed
end

function TethysChlorisCore.preprocess_fields(
    ::Type{FT}, ::Type{TestParams}, data::Dict{String,Any}, params
) where {FT<:AbstractFloat}
    # Example preprocessing: convert all values to Float64
    processed = copy(data)
    processed["calculated"] = processed["required"] + processed["optional"]
    return processed
end

function TethysChlorisCore.get_optional_fields(::Type{TestParams})
    return [:optional]
end

function TethysChlorisCore.get_calculated_fields(::Type{TestParams})
    return [:calculated]
end

Base.@kwdef struct TestAuxVars{FT<:AbstractFloat} <: AbstractAuxiliaryVariables{FT}
    var1::Array{FT,2}
    var2::Array{FT,3}
end

function TethysChlorisCore.get_dimensions(::Type{TestAuxVars}, data)
    return Dict("var1" => (10, 5), "var2" => (10, 5, 3))
end

FT = Float64

@testset "validate_fields" begin
    # Valid case
    valid_data = Dict{String,Any}("required" => 1, "optional" => 2)
    @test_nowarn validate_fields(TestParams, valid_data)

    # Invalid case
    invalid_data = copy(valid_data)
    invalid_data["extraneous"] = 3
    @test_throws ArgumentError validate_fields(TestParams, invalid_data)
end

@testset "get_required_fields" begin
    required_fields = get_required_fields(TestParams)
    @test required_fields == [:required]
end

@testset "initialize" begin
    # Test successful initialization
    @testset "Dict" begin
        data = Dict{String,Any}("required" => 1.0, "optional" => 2.0)
        comp = initialize(Float64, TestParams, data)
        @test comp.required == 1.0
        @test comp.optional == 2.0
        @test comp.calculated == 3.0

        # Test missing required field
        @test_throws ArgumentError initialize(
            Float64, TestParams, Dict{String,Any}("optional" => 2.0)
        )
    end

    @testset "NCDataset" begin
        mktempdir() do path
            filename = joinpath(path, "test.nc")
            ds = NCDataset(filename, "c")
            # Create required variable
            defVar(ds, "required", 1.0, ())
            comp = initialize(Float64, TestParams, ds)
            close(ds)
            @test comp.required == 1.0

            # # Test missing required field
            @test_throws ArgumentError initialize(FT, TestParams, NCDataset(filename, "c"))
        end
    end
end

@testset "get_required_fields" begin
    @test get_required_fields(TestParams) == [:required]
    @test get_required_fields(TestAuxVars) == Symbol[:var1, :var2]
end

@testset "validate_fields" begin
    @test validate_fields(TestParams, Dict{String,Any}()) === nothing
end

@testset "preprocess_fields" begin
    # Test default preprocessing
    data = Dict("test" => 1.0)
    @test preprocess_fields(Float64, TestParams, data, (FT,)) === data

    # Test auxiliary variables preprocessing
    mktempdir() do path
        filename = joinpath(path, "test.nc")
        ds = NCDataset(filename, "c")
        processed = preprocess_fields(Float64, TestAuxVars, ds, (FT,))
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

@testset "Multi-parametric composite types" begin
    Base.@kwdef struct MultiParametricComponent{FT<:AbstractFloat,N,M} <:
                       AbstractModelComponent{FT}
        required::FT
        optional::FT
        calculated::FT
    end

    valid_data = Dict{String,Any}("required" => 1.0, "optional" => 2.0, "calculated" => 3.0)

    initialized = initialize(Float64, MultiParametricComponent, valid_data, (Float64, 2, 3))
end
