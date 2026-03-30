using TethysChlorisCore
using SafeTestsets

@safetestset "Accessors" begin
    include("test-accessors.jl")
end

@safetestset "Check Extraneous Fields" begin
    include("test-check_extraneous_fields.jl")
end

@safetestset "Initialize" begin
    include("test-initialize.jl")
end

@safetestset "Model Components" begin
    include("test-ModelComponents.jl")
end

@safetestset "Options" begin
    include("test-options.jl")
end
