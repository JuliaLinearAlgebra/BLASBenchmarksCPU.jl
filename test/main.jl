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
    @test benchmark_result isa BLASBenchmarks.BenchmarkResult
    plot_directory = mktempdir()
    BLASBenchmarks.plot(
        benchmark_result;
        plot_directory = plot_directory,
    )
end
