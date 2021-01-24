```@meta
CurrentModule = BLASBenchmarksCPU
```

# Usage

Remember to start Julia with multiple threads with e.g. one of the following:
- `julia -t auto`
- `julia -t 4`
- Set the `JULIA_NUM_THREADS` environment variable to `4` **before** starting Julia

## Example 1

```julia
julia> using BLASBenchmarksCPU

julia> benchmark_result = runbench(Float64)

julia> plot_directory = "/foo/bar/baz/"

julia> BLASBenchmarksCPU.plot(benchmark_result; plot_directory)
```

## Example 2

```julia
julia> using BLASBenchmarksCPU

julia> libs = [:Gaius, :Octavian, :OpenBLAS]

julia> sizes = [10, 20, 30]

julia> threaded = true

julia> benchmark_result = runbench(Float64; libs, sizes, threaded)

julia> plot_directory = "/foo/bar/baz/"

julia> BLASBenchmarksCPU.plot(benchmark_result; plot_directory)
```
