
import BLASBenchmarksCPU
import StatsPlots
@testset "Interface" begin
    benchmark_result = BLASBenchmarksCPU.runbench(Float64; sizes = [1, 2, 5, 10, 20, 50, 100, 200], threaded=false, summarystat = BLASBenchmarksCPU.median) #test that threads=false at least doesn't throw somewhere.
    df = BLASBenchmarksCPU.benchmark_result_df(benchmark_result)
    @test df isa BLASBenchmarksCPU.DataFrame
    df[!, :Size] = Float64.(df[!, :Size]);
    df[!, :GFLOPS] = Float64.(df[!, :GFLOPS]);
    df[!, :Seconds] = Float64.(df[!, :Seconds]);
    p = StatsPlots.@df df StatsPlots.plot(:Size, :GFLOPS; group = :Library, legend = :bottomright)
    @test p isa StatsPlots.Plots.Plot
end
