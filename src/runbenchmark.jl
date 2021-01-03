
struct BenchmarkResult{T}
    df::DataFrame
    threaded::Bool
end
function Base.show(io::IO, br::BenchmarkResult{T}) where {T}
    println(io, "Bennchmark Result of Matrix{$T}, threads = $(br.threaded)")
    println(io, br.df)
end

function maybe_sleep(x)
    x > 1e-3 && sleep(x)
end

function benchmark_fun!(
    f!::F, C, A, B, sleep_time, force_belapsed = false, reference = nothing
) where {F}
    maybe_sleep(sleep_time)
    tmin = @elapsed f!(C, A, B)
    isnothing(reference) || @assert C ≈ reference
    if force_belapsed || 2tmin < BenchmarkTools.DEFAULT_PARAMETERS.seconds
        maybe_sleep(sleep_time)
        tmin = min(tmin, @belapsed $f!($C, $A, $B))
    elseif tmin < BenchmarkTools.DEFAULT_PARAMETERS.seconds
        maybe_sleep(sleep_time)
        tmin = min(tmin, @elapsed f!(C, A, B))
        if tmin < 2BenchmarkTools.DEFAULT_PARAMETERS.seconds
            maybe_sleep(sleep_time)
            tmin = min(tmin, @elapsed f!(C, A, B))
        end
    end
    tmin
end
_mat_size(M, N, ::typeof(adjoint)) = (N, M)
_mat_size(M, N, ::typeof(transpose)) = (N, M)
_mat_size(M, N, ::typeof(identity)) = (M, N)
function alloc_mat(_M, _N, memory::Vector{T}, off, f = identity) where {T}
    M, N = _mat_size(_M, _N, f)
    A = f(reshape(view(memory, (off+1):(off+M*N)), (M, N)))
    A, off + align(M*N, T)
end

matmul_sizes(s::Integer) = (s,s,s)
matmul_sizes(mkn::Tuple{Vararg{Integer,3}}) = mkn

junk(::Type{T}) where {T <: Integer} = typemax(T) >> 1
junk(::Type{T}) where {T} = T(NaN)

struct LogSpace
    r::StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}}
end
Base.IteratorSize(::Type{LogSpace}) = Base.HasShape{1}()
"""
  logspace(start, stop, length)

Defines a monotonically increasing range, log spaced when possible. Useful for defining a range of sizes for benchmarks.

```julia
julia> collect(logspace(1,100,3))
3-element Vector{Int64}:
   1
  10
 100

julia> collect(logspace(1,10,3))
3-element Vector{Int64}:
  1
  3
 10

julia> collect(logspace(1,5,3))
3-element Vector{Int64}:
 1
 2
 5

julia> collect(logspace(1,3,3))
3-element Vector{Int64}:
 1
 2
 3
```
"""
logspace(start, stop, length) = LogSpace(range(log(start),log(stop), length = length))
function Base.iterate(ls::LogSpace)
    i_s = iterate(ls.r)
    i_s === nothing && return nothing
    i, _s = i_s
    v = round(Int, exp(i))
    v, (_s, v)
end
function Base.iterate(ls::LogSpace, (s,l))
    i_s = iterate(ls.r, s)
    i_s === nothing && return nothing
    i, _s = i_s
    v = max(round(Int, exp(i)), l+1)
    v, (_s, v)
end
Base.length(ls::LogSpace) = length(ls.r)
Base.size(ls::LogSpace) = (length(ls.r),)
Base.axes(ls::LogSpace) = axes(ls.r)
Base.eltype(::LogSpace) = Int
function runbench(
    ::Type{T} = Float64;
    libs = [:MKL, :OpenBLAS, :PaddedMatrices, :Tullio, :Octavian, :Gaius],
    sizes = logspace(2, 4000, 200),
    threaded::Bool = Threads.nthreads() > 1,
    A_transform = identity,
    B_transform = identity,
    sleep_time = 0.0
) where {T}
    if threaded
        mkl_set_num_threads(NUM_CORES)
        openblas_set_num_threads(NUM_CORES)
    else
        mkl_set_num_threads(1)
        openblas_set_num_threads(1)
    end

    funcs = getfuncs(libs, threaded)
    sizevec = collect(sizes)
    # Hack to workaround https://github.com/JuliaCI/BenchmarkTools.jl/issues/127
    # Use the same memory every time, to reduce accumulation
    max_matrix_sizes = maximum(sizes) do s
        M, K, N = matmul_sizes(s)
        align(M * K, T) + align(K * N, T) + align(M * N, T) * 2
    end
    memory = Vector{T}(undef, max_matrix_sizes)
    library = reduce(vcat, (libs for _ ∈ eachindex(sizes)))
    Nres = length(libs) * length(sizes)
    times = Vector{Float64}(undef, Nres)
    gflop = Vector{Float64}(undef, Nres)
    k = 0

    force_belapsed = true # force when compiling
    
    p = Progress(length(sizes))
    last_perfs = Vector{Tuple{Symbol,Union{Float64,NTuple{3,Int}}}}(undef, length(libs)+1)
    for (j,s) ∈ enumerate(sizes)
        M, K, N = matmul_sizes(s)
        A,  off = alloc_mat(M, K, memory,   0, A_transform)
        B,  off = alloc_mat(K, N, memory, off, B_transform)
        C0, off = alloc_mat(M, N, memory, off)
        C1, off = alloc_mat(M, N, memory, off)
        PaddedMatrices.rand!(PaddedMatrices.local_rng(), A)
        PaddedMatrices.rand!(PaddedMatrices.local_rng(), B)
        last_perfs[1] = (:Size, (M,K,N) .% Int)
        for i ∈ eachindex(funcs)
            C, ref = i == 1 ? (C0, nothing) : (fill!(C1,junk(T)), C0)
            t = benchmark_fun!(
                funcs[i], C, A, B, sleep_time, force_belapsed, ref
            )
            gflops = 2e-9M*K*N / t
            times[(k += 1)] = t
            gflop[k] = gflops
            last_perfs[i+1] = (libs[i], round(gflops,sigdigits=4))
        end
        ProgressMeter.next!(p; showvalues = last_perfs)
        force_belapsed = false
    end
    _sizes = kron(sizes, trues(length(libs)))
    BenchmarkResult{T}(
        DataFrame(Size = _sizes, Library = library, GFLOPS = gflop, Time = times),
        threaded
    )
end


