using Test
using TethysChlorisCore
using NCDatasets: NCDataset, defDim

# Toy component sets mirroring a user-defined model specialization: arbitrary nested
# structs, a custom output level, and a set defining fields of a user-defined type.
struct ToyLeaf{FT}
    field1::Vector{FT}
    field2::Vector{FT}
end

struct ToyHydro{FT}
    scalar::Float64
    high::ToyLeaf{FT}
    low::ToyLeaf{FT}
end

struct ToySoil{FT}
    Osat::FT
    Ohy::FT
end

struct ToySet{FT}
    hydro::ToyHydro{FT}
    soil::ToySoil{FT}
end

struct ToyOutputs <: AbstractOutputsToSave end
import TethysChlorisCore: decrease, outputs_to_save

TethysChlorisCore.decrease(::Type{ToyOutputs}) = NoOutputs
TethysChlorisCore.outputs_to_save(::Type{ToySet}, ::Type{ToyOutputs}) = (:hydro,)
function TethysChlorisCore.outputs_to_save(::Type{ToyHydro}, ::Type{ToyOutputs})
    (:scalar, :high, :low)
end
TethysChlorisCore.outputs_to_save(::Type{ToyLeaf}, ::Type{ToyOutputs}) = (:field1, :field2)

@testset "Output writer" begin
    @testset "output_specs traversal" begin
        specs = output_specs(ToySet, ToyOutputs; source=:state)
        names = [s.name for s in specs]
        @test names == [:field1_H, :field2_H, :field1_L, :field2_L, :scalar]
        @test all(s -> s.group === :hydro, specs)
        @test all(s -> s.source === :state, specs)
        @test all(s -> isempty(s.dims), specs)
        @test all(s -> s.acc_op === :mean, specs)

        inst = ToySet(
            ToyHydro(1.5, ToyLeaf([1.0, 2.0], [7.0]), ToyLeaf([3.0], [8.0])),
            ToySoil(9.0, 9.5),
        )
        get(spec) = spec.extractor(inst)
        @test get(specs[findfirst(s -> s.name === :scalar, specs)]) == 1.5
        @test get(specs[findfirst(s -> s.name === :field1_H, specs)]) == [1.0, 2.0]
        @test get(specs[findfirst(s -> s.name === :field1_L, specs)]) == [3.0]
        @test get(specs[findfirst(s -> s.name === :field2_L, specs)]) == [8.0]

        # the old 2-level naming with a non-struct leaf still works for the generic path
        @test_throws ArgumentError output_specs(ToySet, <:AbstractOutputsToSave)
    end

    @testset "axis_names" begin
        known = (layerbelowsurface=10, crownareas=2)
        @test axis_names((10,); known=known) == [:layerbelowsurface]
        @test axis_names((2,); known=known) == [:crownareas]
        @test axis_names((1,); known=known) == [:axis1]
        @test axis_names((3,); known=known) == [:axis3]
        @test axis_names((2, 10); known=known) == [:crownareas, :layerbelowsurface]
        @test axis_names((10, 2); known=known) == [:layerbelowsurface, :crownareas]
        @test axis_names((2, 2); known=known) == [:crownareas, :axis2]
        @test axis_names((); known=known) == []
    end

    @testset "chunksizes" begin
        @test chunksizes([(:time, 71), (:aux, 3)]) == (32, 3)
        @test chunksizes([(:aux, 3), (:naver, 5)]; naver_chunk=8) == (3, 8)
        @test chunksizes([(:aux, 3)], time_chunk=7) == (3,)
        @test chunksizes([(:time, 5), (:m, 2), (:n, 2), (:naver, 9)]) == (32, 2, 2, 1)
    end

    @testset "buffer round-trip (time first)" begin
        mktempdir() do tmp
            ds = NCDataset(joinpath(tmp, "b.nc"), "c")
            defDim(ds, "time", Inf)
            defDim(ds, "aux", 3)
            v = add_variable!(ds, :x, Float64, (:time, :aux); chunksizes=(32, 3))

            tb = TimeBuffers(; buffer_len=4)
            getv = (g, n) -> v

            store_buffer!(tb, getv, "g", :x, 1.0, 1, Float64)
            store_buffer!(tb, getv, "g", :x, [2.0, 2.5, 3.0], 2, Float64)
            @test size(tb.buffers[("g", :x)]) == (4, 3)
            @test tb.layouts[("g", :x)] == false
            @test tb.fill == 0

            tb.fill = 2
            flush_buffers!(tb, getv, 1:2)
            @test tb.fill == 0
            @test Array(v)[1] == 1.0
            @test Array(v)[2, :] == [2.0, 2.5, 3.0]
            close(ds)
        end
    end

    @testset "buffer round-trip (time last)" begin
        mktempdir() do tmp
            ds = NCDataset(joinpath(tmp, "b.nc"), "c")
            defDim(ds, "naver", Inf)
            defDim(ds, "aux", 3)
            w = add_variable!(ds, :y, Float64, (:aux, :naver); chunksizes=(3, 32))

            tb = TimeBuffers(; buffer_len=4)
            getv = (g, n) -> w

            store_buffer!(tb, getv, "g", :y, [1.0, 1.5, 2.0], 1, Float64)
            store_buffer!(tb, getv, "g", :y, 0.0, 2, Float64)
            @test size(tb.buffers[("g", :y)]) == (3, 4)
            @test tb.layouts[("g", :y)] == true

            tb.fill = 2
            flush_buffers!(tb, getv, 1:2)
            @test Array(w)[:, 1] == [1.0, 1.5, 2.0]
            @test Array(w)[:, 2] == [0.0, 0.0, 0.0]
            close(ds)
        end
    end

    @testset "cell_stats and domain_stats" begin
        m, s = cell_stats([1.0, 2.0, 3.0], Float64)
        @test m == 2.0
        @test s == sqrt(sum(abs2, x - 2.0 for x in [1.0, 2.0, 3.0]) / 2)

        m, s = cell_stats([1.0, NaN, 3.0], Float64)
        @test m == 2.0
        m, s = cell_stats([NaN, NaN], Float64)
        @test isnan(m) && isnan(s)
        m, s = cell_stats([5.0], Float64)
        @test isnan(s) && m == 5.0

        vals = [1.0 10.0; 3.0 30.0; NaN 50.0]
        means, stds = domain_stats(vals, Float64)
        @test means[1] == 2.0 && stds[1] == sqrt(2.0)
        @test means[2] == 30.0
        m, s = domain_stats([1.0, 2.0], Float64)
        @test m == 1.5
    end

    @testset "assign helpers" begin
        mktempdir() do tmp
            ds = NCDataset(joinpath(tmp, "b.nc"), "c")
            defDim(ds, "time", Inf)
            defDim(ds, "m", 2)
            defDim(ds, "n", 2)
            defDim(ds, "naver", Inf)
            v = add_variable!(ds, :s, Float64, (:time,))
            w = add_variable!(ds, :vv, Float64, (:time, :m, :n))
            avg = add_variable!(ds, :a, Float64, (:m, :n, :naver); chunksizes=(2, 2, 8))

            assign_slice!(v, 2.0, 1)
            assign_slice!(w, [1.0 3.0; 2.0 4.0], 2)

            acc = [1.0, 2.0, 3.0, 4.0]
            assign_average_slice!(avg, acc, 1, (2, 2))
            @test Array(v)[1] == 2.0
            @test Array(w)[2, :, :] == [1.0 3.0; 2.0 4.0]
            @test Array(avg)[:, :, 1] == [1.0 3.0; 2.0 4.0]
            close(ds)
        end
    end
end
