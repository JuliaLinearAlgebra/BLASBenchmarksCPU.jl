
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
    f!, C, A, B, sleep_time, force_belapsed = false, reference = nothing
)
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

matmul_sizes(s::Integer) = (s,s,s)
matmul_sizes(mkn::Tuple{Vararg{Integer,3}}) = mkn

junk(::Type{T}) where {T <: Integer} = typemax(T) >> 1
junk(::Type{T}) where {T} = T(NaN)
function logspace(start, stop, length)
    round.(Int, exp.(range(log(start), log(stop), length=length)))
end
function runbench(
    ::Type{T} = Float64;
    libs = [:MKL, :OpenBLAS, :PaddedMatrices, :Tullio, :Octavian, :Gaius],
    sizes = vcat(2:255, logspace(256, 4000, 200)),
    threaded::Bool = Threads.nthreads() > 1,
    A_transform = identity,
    B_transform = identity,
    sleep_time = 0.0
) where {T}
    if threaded
        mkl_set_num_threads(VectorizationBase.NUM_CORES)
        openblas_set_num_threads(VectorizationBase.NUM_CORES)
    else
        mkl_set_num_threads(1)
        openblas_set_num_threads(1)
    end

    funcs = getfuncs(libs, threaded)

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
        A = A_transform(rand(T, M, K))
        B = B_transform(rand(T, K, N))
        C0 = Matrix{T}(undef, M, N)
        C1 = Matrix{T}(undef, M, N)
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


