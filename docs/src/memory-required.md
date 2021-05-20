```@meta
CurrentModule = BLASBenchmarksCPU
```

# Memory Required for Large Matrices

This table shows how much memory is required for four matrices of the given size and type. (We need four matrices: `A`, `B`, `C1`, and `C2`.)

| Matrix Size | Float64 Memory | Float32 Memory | Int64 Memory | Int32 Memory |
| ----------- |  ------ | ------ | ------ | ------ |
| 1k by 1k | 0.03 GiB | 0.01 GiB | 0.03 GiB | 0.01 GiB |
| 2k by 2k | 0.12 GiB | 0.06 GiB | 0.12 GiB | 0.06 GiB |
| 3k by 3k | 0.27 GiB | 0.13 GiB | 0.27 GiB | 0.13 GiB |
| 4k by 4k | 0.48 GiB | 0.24 GiB | 0.48 GiB | 0.24 GiB |
| 5k by 5k | 0.75 GiB | 0.37 GiB | 0.75 GiB | 0.37 GiB |
| 6k by 6k | 1.07 GiB | 0.54 GiB | 1.07 GiB | 0.54 GiB |
| 7k by 7k | 1.46 GiB | 0.73 GiB | 1.46 GiB | 0.73 GiB |
| 8k by 8k | 1.91 GiB | 0.95 GiB | 1.91 GiB | 0.95 GiB |
| 9k by 9k | 2.41 GiB | 1.21 GiB | 2.41 GiB | 1.21 GiB |
| 10k by 10k | 2.98 GiB | 1.49 GiB | 2.98 GiB | 1.49 GiB |
| 11k by 11k | 3.61 GiB | 1.8 GiB | 3.61 GiB | 1.8 GiB |
| 12k by 12k | 4.29 GiB | 2.15 GiB | 4.29 GiB | 2.15 GiB |
| 13k by 13k | 5.04 GiB | 2.52 GiB | 5.04 GiB | 2.52 GiB |
| 14k by 14k | 5.84 GiB | 2.92 GiB | 5.84 GiB | 2.92 GiB |
| 15k by 15k | 6.71 GiB | 3.35 GiB | 6.71 GiB | 3.35 GiB |
| 16k by 16k | 7.63 GiB | 3.81 GiB | 7.63 GiB | 3.81 GiB |
| 17k by 17k | 8.61 GiB | 4.31 GiB | 8.61 GiB | 4.31 GiB |
| 18k by 18k | 9.66 GiB | 4.83 GiB | 9.66 GiB | 4.83 GiB |
| 19k by 19k | 10.76 GiB | 5.38 GiB | 10.76 GiB | 5.38 GiB |
| 20k by 20k | 11.92 GiB | 5.96 GiB | 11.92 GiB | 5.96 GiB |
| 30k by 30k | 26.82 GiB | 13.41 GiB | 26.82 GiB | 13.41 GiB |
| 40k by 40k | 47.68 GiB | 23.84 GiB | 47.68 GiB | 23.84 GiB |
| 50k by 50k | 74.51 GiB | 37.25 GiB | 74.51 GiB | 37.25 GiB |
| 60k by 60k | 107.29 GiB | 53.64 GiB | 107.29 GiB | 53.64 GiB |
| 70k by 70k | 146.03 GiB | 73.02 GiB | 146.03 GiB | 73.02 GiB |
| 80k by 80k | 190.73 GiB | 95.37 GiB | 190.73 GiB | 95.37 GiB |
| 90k by 90k | 241.4 GiB | 120.7 GiB | 241.4 GiB | 120.7 GiB |
| 100k by 100k | 298.02 GiB | 149.01 GiB | 298.02 GiB | 149.01 GiB |

## Generating These Tables

```julia
mem_req(s, ::Type{T}) where {T} = 4s^2*sizeof(T) / (1 << 30)

function print_table(types::Vector{DataType}, Ns = nothing)
    println("| Matrix Size | $(join(types, " Memory | ")) Memory |")
    println("| ----------- | $(repeat(" ------ |", length(types)))")
    if Ns isa Nothing
        _Ns = sort(unique(vcat(collect(1:1:20), collect(20:10:100))))
    else
        _Ns = Ns
    end
    for N in _Ns
        mem = mem_req.(N * 1_000, types)
        m = round.(mem; digits = 2)
        println("| $(N)k by $(N)k | $(join(m, " GiB | ")) GiB |")
    end
    return nothing
end
```

```julia
julia> print_table([Float64, Float32, Int64, Int32])
```
