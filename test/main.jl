sizes = [10, 20, 30]
if Threads.nthreads() > 1
    threaded = true
else
    threaded = false
end
for T in [Float64, Float32]
    @info "" T sizes threaded
    benchmark_result = runbench(
        T;
        sizes = sizes,
        threaded = threaded,
    )
    @test benchmark_result isa BLASBenchmarksCPU.BenchmarkResult
    @test benchmark_result_type(benchmark_result) === T
    df = benchmark_result_df(benchmark_result)
    @test df isa BLASBenchmarksCPU.DataFrame
    @test df.Sizes == sizes
    @test df.Sizes !== sizes # do we need this?
    plot_directory = mktempdir()
    BLASBenchmarksCPU.plot(
        benchmark_result;
        plot_directory = plot_directory,
    )
end
