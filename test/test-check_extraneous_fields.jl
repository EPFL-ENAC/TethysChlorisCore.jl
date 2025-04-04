using Test
using TethysChlorisCore

FT = Float64
struct MockComponent{FT} <: AbstractModelComponent{FT}
    field1::FT
    field2::FT
    field3::FT
end

function get_optional_fields(::Type{MockComponent})
    return [:field1]
end

function get_calculated_fields(::Type{MockComponent})
    return [:field3]
end

@testset "check_extraneous_fields" begin
    # Valid case - only required fields
    data = Dict{String,Any}("field1" => 1, "field2" => 2, "field4" => 3)

    @test_nowarn check_extraneous_fields(
        MockComponent{FT}, data, ["field1", "field2", "field4"]
    )
    @test_nowarn check_extraneous_fields(
        MockComponent{FT}, data, NTuple{3,String}(("field1", "field2", "field4"))
    )
    @test_throws MethodError check_extraneous_fields(
        MockComponent{FT}, data, [:field1, :field2]
    )
    @test_throws MethodError check_extraneous_fields(
        MockComponent{FT}, data, NTuple{2,Symbol}((:field1, :field2))
    )
    @test_throws ArgumentError check_extraneous_fields(MockComponent{FT}, data, ["field1"])
    @test_throws ArgumentError check_extraneous_fields(MockComponent{FT}, data)
end
