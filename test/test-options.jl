using Test
using TethysChlorisCore
using SimpleNonlinearSolve: SimpleNonlinearSolve

@testset "ODEOptions" begin
    @testset "Construction" begin
        opts = ODEOptions()
        @test opts.abstol == 1e-6
        @test opts.reltol == 1e-3

        opts1 = ODEOptions(abstol=1e-8)
        @test opts1.abstol == 1e-8
        @test opts1.reltol == 1e-3  # Default value

        opts2 = ODEOptions(reltol=1e-5)
        @test opts2.abstol == 1e-6  # Default value
        @test opts2.reltol == 1e-5
    end

    @testset "Type hierarchy" begin
        opts = ODEOptions()
        @test opts isa AbstractODEOptions
        @test opts isa AbstractOptions
    end

    @testset "Field types with Float32" begin
        opts = ODEOptions(abstol=Float32(1e-4), reltol=Float32(1e-2))
        @test opts.abstol isa AbstractFloat
        @test opts.reltol isa AbstractFloat
        @test opts.abstol == Float32(1e-4)
        @test opts.reltol == Float32(1e-2)
    end

    @testset "Field types with Float64" begin
        opts = ODEOptions(abstol=Float64(1e-10), reltol=Float64(1e-8))
        @test opts.abstol isa AbstractFloat
        @test opts.reltol isa AbstractFloat
        @test opts.abstol == Float64(1e-10)
        @test opts.reltol == Float64(1e-8)
    end

    @testset "Immutability" begin
        opts = ODEOptions()
        # Verify struct is immutable by checking it's not mutable
        @test !ismutable(opts)
    end
end

@testset "ZeroFindingStrategies" begin
    @testset "Type hierarchy" begin
        strategy = SimpleBrentStrategy(Float64)
        @test strategy isa AbstractZeroFindingStrategies
        @test strategy isa AbstractOptions
    end

    @testset "SimpleBrentStrategy with Float64 defaults" begin
        FT = Float64
        strategy = SimpleBrentStrategy(FT)

        @test strategy.method isa SimpleNonlinearSolve.Brent
        @test haskey(strategy.kwargs, :abstol)
        @test haskey(strategy.kwargs, :reltol)
        @test haskey(strategy.kwargs, :maxiters)

        # Check default values
        expected_tol = real(oneunit(FT)) * (eps(real(one(FT))))^(4 // 5)
        @test strategy.kwargs.abstol ≈ expected_tol
        @test strategy.kwargs.reltol ≈ expected_tol
        @test strategy.kwargs.maxiters == 1000
    end

    @testset "SimpleBrentStrategy with Float32 defaults" begin
        FT = Float32
        strategy = SimpleBrentStrategy(FT)

        @test strategy.method isa SimpleNonlinearSolve.Brent

        # Check default values for Float32
        expected_tol = real(oneunit(FT)) * (eps(real(one(FT))))^(4 // 5)
        @test strategy.kwargs.abstol ≈ expected_tol
        @test strategy.kwargs.reltol ≈ expected_tol
        @test strategy.kwargs.maxiters == 1000
    end

    @testset "SimpleBrentStrategy with custom tolerances" begin
        FT = Float64
        custom_abstol = FT(1e-10)
        custom_reltol = FT(1e-8)
        custom_maxiters = 500

        strategy = SimpleBrentStrategy(
            FT; abstol=custom_abstol, reltol=custom_reltol, maxiters=custom_maxiters
        )

        @test strategy.kwargs.abstol == custom_abstol
        @test strategy.kwargs.reltol == custom_reltol
        @test strategy.kwargs.maxiters == custom_maxiters
    end

    @testset "SimpleBrentStrategy with partial custom tolerances" begin
        FT = Float64
        custom_abstol = FT(1e-10)
        expected_reltol = real(oneunit(FT)) * (eps(real(one(FT))))^(4 // 5)

        strategy = SimpleBrentStrategy(FT; abstol=custom_abstol)

        @test strategy.kwargs.abstol == custom_abstol
        @test strategy.kwargs.reltol ≈ expected_reltol  # Should use default
        @test strategy.kwargs.maxiters == 1000  # Should use default
    end

    @testset "default_tolerances for SimpleNonlinearSolve" begin
        method = SimpleNonlinearSolve.Brent()

        # Float64
        abstol, reltol, maxiters = TethysChlorisCore.default_tolerances(method, Float64)
        expected_tol = real(oneunit(Float64)) * (eps(real(one(Float64))))^(4 // 5)
        @test abstol ≈ expected_tol
        @test reltol ≈ expected_tol
        @test maxiters == 1000

        # Float32
        abstol, reltol, maxiters = TethysChlorisCore.default_tolerances(method, Float32)
        expected_tol = real(oneunit(Float32)) * (eps(real(one(Float32))))^(4 // 5)
        @test abstol ≈ expected_tol
        @test reltol ≈ expected_tol
        @test maxiters == 1000
    end

    @testset "Kwargs NamedTuple structure" begin
        strategy = SimpleBrentStrategy(Float64; abstol=1e-8, reltol=1e-6, maxiters=100)

        @test strategy.kwargs isa NamedTuple
        @test length(strategy.kwargs) == 3
        @test keys(strategy.kwargs) == (:abstol, :reltol, :maxiters)
    end
end

@testset "find_root integration" begin
    @testset "Missing method" begin
        strategy = ZeroFindingStrategies(2.0, (;))
        @test_throws MethodError find_root(x -> x^2 - 4, 1.0, strategy)
    end

    @testset "Simple quadratic function with bracket" begin
        # f(x) = x^2 - 4, root at x = ±2
        # Use explicit bracket to avoid search issues
        f(x) = x^2 - 4
        bracket = (1.0, 3.0)  # Bracket containing root at x=2
        strategy = SimpleBrentStrategy(Float64)

        root, residual = find_root(f, bracket, strategy)

        @test root ≈ 2 atol=1e-5
        @test residual ≈ 0 atol=1e-5
    end

    @testset "Custom tolerance affects accuracy" begin
        f(x) = sin(x)
        bracket = (3.0, 3.5)  # Bracket around root at π

        # Loose tolerance
        strategy_loose = SimpleBrentStrategy(Float64; abstol=1e-3, reltol=1e-3)
        root_loose, residual_loose = find_root(f, bracket, strategy_loose)

        # Tight tolerance
        strategy_tight = SimpleBrentStrategy(Float64; abstol=1e-10, reltol=1e-10)
        root_tight, residual_tight = find_root(f, bracket, strategy_tight)

        @test residual_loose ≈ 0 atol=1e-2
        @test residual_tight ≈ 0 atol=1e-9
        @test root_loose ≈ π atol=0.01
        @test root_tight ≈ π atol=1e-5
    end

    @testset "Custom search range" begin
        f(x) = x - 5
        x0 = 0.0
        strategy = SimpleBrentStrategy(Float64)

        # Should find root with different search ranges
        root1, residual1 = find_root(f, x0, strategy; search_range=10.0)
        root2, residual2 = find_root(f, x0, strategy; search_range=20.0)

        @test root1 ≈ 5 atol=1e-5
        @test residual1 ≈ 0 atol=1e-5
        @test root2 ≈ 5 atol=1e-5
        @test residual2 ≈ 0 atol=1e-5
    end

    @testset "Float32 precision" begin
        # f(x) = x - 2, root at x = 2
        f(x) = Float32(x - 2)
        bracket = (Float32(1.0), Float32(3.0))
        strategy = SimpleBrentStrategy(Float32)

        root, residual = find_root(f, bracket, strategy)

        @test root isa Float32
        @test residual isa Float32
        @test root ≈ 2 atol=1e-4
    end

    @testset "Error handling for failed convergence" begin
        # This test verifies that find_root properly handles convergence failures
        # Create a function and parameters that might challenge the solver
        f(x) = sign(x)  # Discontinuous function - difficult to solve
        x0 = 1.0
        strategy = SimpleBrentStrategy(Float64; maxiters=1)  # Very few iterations

        @test_throws Exception find_root(f, x0, strategy; search_range=0.1)
    end
end
