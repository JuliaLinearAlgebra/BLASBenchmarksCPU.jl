
import BLASBenchmarksCPU
import StatsPlots
@testset "Interface" begin
    benchmark_result = BLASBenchmarksCPU.runbench(Float64; sizes = [1, 2, 5, 10, 20, 50, 100, 200], threaded=false, summarystat = BLASBenchmarksCPU.median) #test that threads=false at least doesn't throw somewhere.
    dfmin = BLASBenchmarksCPU.benchmark_result_df(benchmark_result) # minimum
    dfmedian = BLASBenchmarksCPU.benchmark_result_df(benchmark_result, :median)
    dfmean = BLASBenchmarksCPU.benchmark_result_df(benchmark_result, :mean)
    dfmax = BLASBenchmarksCPU.benchmark_result_df(benchmark_result, :maximum)
    @test_throws ArgumentError  BLASBenchmarksCPU.benchmark_result_df(benchmark_result, :foobar)
    @test dfmin isa BLASBenchmarksCPU.DataFrame
    @test dfmedian isa BLASBenchmarksCPU.DataFrame
    @test dfmean isa BLASBenchmarksCPU.DataFrame
    @test dfmax isa BLASBenchmarksCPU.DataFrame
    for df ∈ (dfmin,dfmedian,dfmean,dfmax)
        df[!, :Size] = Float64.(df[!, :Size]);
        df[!, :GFLOPS] = Float64.(df[!, :GFLOPS]);
        df[!, :Seconds] = Float64.(df[!, :Seconds]);
        p = StatsPlots.@df df StatsPlots.plot(:Size, :GFLOPS; group = :Library, legend = :bottomright)
        @test p isa StatsPlots.Plots.Plot
    end
    @test all(dfmin[!, :GFLOPS] .≥ dfmedian[!, :GFLOPS])
    @test all(dfmin[!, :GFLOPS] .≥ dfmean[!, :GFLOPS])
    @test all(dfmin[!, :GFLOPS] .≥ dfmax[!, :GFLOPS])
    @test any(dfmin[!, :GFLOPS] .≠ dfmedian[!, :GFLOPS])
    @test any(dfmin[!, :GFLOPS] .≠ dfmean[!, :GFLOPS])
    @test any(dfmin[!, :GFLOPS] .≠ dfmax[!, :GFLOPS])
    @test any(dfmedian[!, :GFLOPS] .≥ dfmax[!, :GFLOPS])
    @test any(dfmean[!, :GFLOPS] .≥ dfmax[!, :GFLOPS])
    @test any(dfmedian[!, :GFLOPS] .≠ dfmax[!, :GFLOPS])
    @test any(dfmean[!, :GFLOPS] .≠ dfmax[!, :GFLOPS])
end
