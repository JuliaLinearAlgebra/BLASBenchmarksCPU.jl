struct BenchmarkResult{T,I<:Union{Int,NTuple{3,Int}}}
    libraries::Vector{Symbol}
    sizes::Vector{I}
    gflops::Array{Float64,3}
    times::Array{Float64,3}
    threaded::Bool
end
function BenchmarkResult{T}(libraries, sizes, gflops, times, threaded) where {T}
    gflopsperm = permutedims(gflops, (2,3,1))
    timesperm = permutedims(times, (2,3,1))
    I = eltype(sizes)
    BenchmarkResult{T,I}(libraries, convert(Vector{I},sizes), gflopsperm, timesperm, threaded)
end

"""
    benchmark_result_type(benchmark_result::BenchmarkResult)
"""
function benchmark_result_type(::BenchmarkResult{T}) where {T}
    return T
end

function get_measure_index(measure::Symbol)::Int
    j = findfirst(==(measure), (:minimum,:median,:mean,:maximum,:hmean))
    if j === nothing
        throw(ArgumentError("`measure` argument must be one of (:minimum,:median,:mean,:maximum,:hmean), but was $(repr(measure))."))
    end
    return j
end
function _benchmark_result_df(sizes, libraries, mat, measure)
    j = get_measure_index(measure)
    df = DataFrame(Size = sizes)
    for i ∈ eachindex(libraries)
        setproperty!(df, libraries[i], mat[:,i,j])
    end
    return df
end
function _benchmark_result_df(br::BenchmarkResult, s::Symbol = :gflops, measure = :minimum)
    _benchmark_result_df(br.sizes, br.libraries, getproperty(br, s), measure)
end


"""
    benchmark_result_df(benchmark_result::BenchmarkResult, `measure` = :minimum)

`measure` refers to the BenchmarkTools summary on times. Valid options are:
`:minimum`, `:medain`, `:mean`, `:maximum`, and `:hmean`.

 -  `:minimum` would yield the maximum `GFLOPS`, and would be the usual estimate used in Julia.
 - `:hmean`, the harmonic mean of the times, is usful if you want an average GFLOPS, instead of a GFLOPS computed with the average times.
"""
function benchmark_result_df(benchmark_result::BenchmarkResult, measure = :minimum)
    df = _benchmark_result_df(benchmark_result, :times, measure)
    df = stack(df, Not(:Size), variable_name = :Library, value_name = :Seconds)
    df.GFLOPS = @. 2e-9 * matmul_length(df.Size) ./ df.Seconds
    return df
end

"""
    benchmark_result_threaded(benchmark_result::BenchmarkResult)
"""
function benchmark_result_threaded(benchmark_result::BenchmarkResult)
    return benchmark_result.threaded
end

function Base.show(io::IO, br::BenchmarkResult{T}) where {T}
    println(io, "Benchmark Result of Matrix{$T}, threaded = $(br.threaded)")
    df = _benchmark_result_df(br)
    println(io, df)
end

function maybe_sleep(x)
    x > 1e-3 && sleep(x)
end

function benchmark_fun!(
    f!::F,
    C,
    A,
    B,
    sleep_time,
    discard_first,
    reference,
    comment::String, # `comment` is a place to put the library name, the dimensions of the matrices, etc.
) where {F}
  maybe_sleep(sleep_time)
  if discard_first
    @elapsed f!(C, A, B)
  end
  t0 = @elapsed f!(C, A, B)
  if (reference !== nothing) && (!(C ≈ reference))
    msg = "C is not approximately equal to reference"
    @error(msg, comment)
    throw(ErrorException(msg))
  end
  if 2t0 < BenchmarkTools.DEFAULT_PARAMETERS.seconds
    maybe_sleep(sleep_time)
    br = @benchmark $f!($C, $A, $B)
    tmin = min(1e-9minimum(br).time, t0)
    tmedian = 1e-9median(br).time
    tmean = 1e-9mean(br).time
    tmax = 1e-9maximum(br).time # We'll exclude the first for this...
    thmean⁻¹ = 1e9mean(inv, br.times)
  else
    maybe_sleep(sleep_time)
    t1 = @elapsed f!(C, A, B)
    maybe_sleep(sleep_time)
    t2 = @elapsed f!(C, A, B)
    if (t0+t1) < 4BenchmarkTools.DEFAULT_PARAMETERS.seconds
      maybe_sleep(sleep_time)
      t3 = @elapsed f!(C, A, B)
      tmin = minimum((t0, t1, t2, t3))
      tmedian = median((t0, t1, t2, t3))
      tmean = mean((t0, t1, t2, t3))
      tmax = maximum((t0, t1, t2, t3))
      thmean⁻¹ = mean(inv, (t0, t1, t2, t3))
    else
      tmin = minimum((t0, t1, t2))
      tmedian = median((t0, t1, t2))
      tmean = mean((t0, t1, t2))
      tmax = maximum((t0, t1, t2))
      thmean⁻¹ = mean(inv, (t0, t1, t2))
    end
  end
  return tmin, tmedian, tmean, tmax, thmean⁻¹
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
matmul_length(s) = prod(matmul_sizes(s))

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
Base.convert(::Type{Vector{Int}}, l::LogSpace) = collect(l)

"""
    all_libs()
"""
function all_libs()
    libs = Symbol[
        :BLIS,
        :Gaius,
        :MKL,
        :Octavian,
        :OpenBLAS,
        :Tullio,
        :LoopVectorization
    ]
    return libs
end

function _integer_libs()
    libs_to_exclude = Symbol[:BLIS, :MKL, :OpenBLAS]
    return sort(unique(setdiff(all_libs(), libs_to_exclude)))
end

"""
    default_libs(T)
"""
function default_libs(::Type{T}) where {T}
    if T <: Integer
        return _integer_libs()
    else
        return all_libs()
    end
end

function luflop(m, n=m; innerflop=2)
  sum(1:min(m, n)) do k
    invflop = 1
    scaleflop = isempty(k+1:m) ? 0 : sum(k+1:m)
    updateflop = isempty(k+1:n) ? 0 : sum(k+1:n) do j
      isempty(k+1:m) ? 0 : sum(k+1:m) do i
        innerflop
      end
    end
    invflop + scaleflop + updateflop
  end * 1e-9
end
gemmflop(m,n,k) = 2e-9m*n*k

"""
    runbench(T = Float64;
             libs = default_libs(T),
             sizes = logspace(2, 4000, 200),
             threaded::Bool = Threads.nthreads() > 1,
             A_transform = identity,
             B_transform = identity,
             sleep_time = 0.0)

 - T: The element type of the matrices.
 - libs: Libraries to benchmark.
 - sizes: Sizes of matrices to benchmark. Must be an iterable with either
          `eltype(sizes) === Int` or `eltype(sizes) === NTuple{3,Int}`.
          If the former, the matrices are square, with each dimension equal to the value.
          If `i::NTuple{3,Int}`, it benchmarks `C = A * B` where `A` is `i[1]` by `i[2]`,
            `B` is `i[2]` by `i[3]` and `C` is `i[1]` by `i[3]`.
 - threaded: Should it benchmark multithreaded implementations?
 - A_transform: a function to apply to `A`. Defaults to `identity`, but can be `adjoint`.
 - B_transofrm: a function to apply to `B`. Defaults to `identity`, but can be `adjoint`.
 - sleep_time: The use of this keyword argument is discouraged. If set, it will call `sleep`
       in between benchmarks, the idea being to help keep the CPU cool. This is an unreliable
       means of trying to get more reliable benchmarks. Instead, it's reccommended you disable
       your systems turbo. Disabling it -- and reenabling when you're done benchmarking --
       should be possible without requiring a reboot.

"""
function runbench(
  ::Type{T} = Float64;
  libs = default_libs(T),
  sizes = logspace(2, 4000, 200),
  threaded::Bool = Threads.nthreads() > 1,
  A_transform = identity,
  B_transform = identity,
  sleep_time = 0.0
) where {T}
  if threaded
    mkl_set_num_threads(num_cores())
    openblas_set_num_threads(num_cores())
    blis_set_num_threads(num_cores())
  else
    mkl_set_num_threads(1)
    openblas_set_num_threads(1)
    blis_set_num_threads(1)
  end
  benchtime = BenchmarkTools.DEFAULT_PARAMETERS.seconds
  BenchmarkTools.DEFAULT_PARAMETERS.seconds = 0.5
  funcs = getfuncs(libs, threaded)
  sizevec = collect(sizes)
  # Hack to workaround https://github.com/JuliaCI/BenchmarkTools.jl/issues/127
  # Use the same memory every time, to reduce accumulation
  max_matrix_sizes = maximum(sizevec) do s
    M, K, N = matmul_sizes(s)
    align(M * K, T) + align(K * N, T) + align(M * N, T) * 2
  end
  memory = Vector{T}(undef, max_matrix_sizes)
  library = reduce(vcat, (libs for _ ∈ eachindex(sizevec)))
  times = Array{Float64}(undef, 5, length(sizes), length(libs))
  gflop = similar(times);

  discard_first = true # force when compiling

  p = Progress(length(sizes))
  gflop_report_type = NamedTuple{(:MedianGFLOPS, :MaxGFLOPS), Tuple{Float64, Float64}}
  last_perfs = Vector{Tuple{Symbol,Union{gflop_report_type,NTuple{3,Int}}}}(undef, length(libs)+1)
  for _j in 0:length(sizevec)-1
    if iseven(_j)
      j = (_j >> 1) + 1
    else
      j = length(sizevec) - (_j >> 1)
    end
    s = sizevec[j]
    M, K, N = matmul_sizes(s)
    A,  off = alloc_mat(M, K, memory,   0, A_transform)
    B,  off = alloc_mat(K, N, memory, off, B_transform)
    rand!(A); rand!(B);
    C0, off = alloc_mat(M, N, memory, off)
    C1, off = alloc_mat(M, N, memory, off)
    last_perfs[1] = (:Size, (M,K,N) .% Int)
    for i ∈ eachindex(funcs)
      C, ref = i == 1 ? (C0, nothing) : (fill!(C1,junk(T)), C0)
      lib = library[i]
      comment = "lib=$(lib), M=$(M), K=$(K), N=$(N)"
      t = benchmark_fun!(
        funcs[i],
        C,
        A,
        B,
        sleep_time,
        discard_first,
        ref,
        comment,
      )
      gffactor = gemmflop(M,K,N)
      @inbounds for k ∈ 1:4
        times[k,j,i] = t[k]
        gflop[k,j,i] = gffactor / t[k]
      end
      times[5,j,i] = inv(t[5])
      gflop[5,j,i] = gffactor * t[5]
      gflops = round.((gflop[1,j,i], gflop[2,j,i]), sigdigits = 4)
      gflops = (
        MedianGFLOPS = round(gflop[2,j,i], sigdigits = 4),
        MaxGFLOPS = round(gflop[1,j,i], sigdigits = 4)
      )
      last_perfs[i+1] = (libs[i], gflops)
    end
    ProgressMeter.next!(p; showvalues = last_perfs)
    if isodd(_j)
      discard_first = false
    end
  end
  BenchmarkTools.DEFAULT_PARAMETERS.seconds = benchtime # restore previous state
  BenchmarkResult{T}(libs, sizes, gflop, times, threaded)
end

const LUFUNCS = Dict(:RecursiveFactorization => RecursiveFactorization.lu!, :MKL => lumkl!, :OpenBLAS => luopenblas!)
struct LUWrapperFunc{F}; f::F; end
(lu::LUWrapperFunc)(A,B,C) = lu.f(copyto!(A,B))
function runlubench(
  ::Type{T} = Float64;
  libs = [:RecursiveFactorization, :MKL, :OpenBLAS],
  sizes = logspace(2, 4000, 200),
  threaded::Bool = Threads.nthreads() > 1,
  A_transform = identity,
  B_transform = identity,
  sleep_time = 0.0
) where {T}
  funcs = LUWrapperFunc.(getindex.(Ref(LUFUNCS), libs))
  if threaded
    mkl_set_num_threads(num_cores())
    openblas_set_num_threads(num_cores())
  else
    mkl_set_num_threads(1)
    openblas_set_num_threads(1)
  end
  benchtime = BenchmarkTools.DEFAULT_PARAMETERS.seconds
  BenchmarkTools.DEFAULT_PARAMETERS.seconds = 0.5
  sizevec = collect(sizes)
  # Hack to workaround https://github.com/JuliaCI/BenchmarkTools.jl/issues/127
  # Use the same memory every time, to reduce accumulation
  max_matrix_sizes = 2maximum(sizevec)^2 + (256 ÷ sizeof(T))
  memory = Vector{T}(undef, max_matrix_sizes)
  library = reduce(vcat, (libs for _ ∈ eachindex(sizevec)))
  times = Array{Float64}(undef, 5, length(sizes), length(libs))
  gflop = similar(times);

  discard_first = true # force when compiling

  p = Progress(length(sizes))
  gflop_report_type = NamedTuple{(:MedianGFLOPS, :MaxGFLOPS), Tuple{Float64, Float64}}
  last_perfs = Vector{Tuple{Symbol,Union{gflop_report_type,NTuple{2,Int}}}}(undef, length(libs)+1)
  for _j in 0:length(sizevec)-1
    if iseven(_j)
      j = (_j >> 1) + 1
    else
      j = length(sizevec) - (_j >> 1)
    end
    N = sizevec[j]
    M = N
    A,  off = alloc_mat(M, N, memory,   0, A_transform)
    rand!(A); #rand!(B);
    @inbounds for n ∈ 1:N, m ∈ 1:M
      A[m,n] = (A[m,n] + (m == n))
    end
    B, off = alloc_mat(M, N, memory, off, B_transform)
    last_perfs[1] = (:Size, (M,N) .% Int)
    for i ∈ eachindex(funcs)
      lib = library[i]
      comment = "lib=$(lib), M=$(M), N=$(N)"
      t = benchmark_fun!(
        funcs[i],
        B,
        A,
        nothing,
        sleep_time,
        discard_first,
        nothing,
        comment,
      )
      gffactor = luflop(M,N)
      @inbounds for k ∈ 1:4
        times[k,j,i] = t[k]
        gflop[k,j,i] = gffactor / t[k]
      end
      times[5,j,i] = inv(t[5])
      gflop[5,j,i] = gffactor * t[5]
      gflops = round.((gflop[1,j,i], gflop[2,j,i]), sigdigits = 4)
      gflops = (
        MedianGFLOPS = round(gflop[2,j,i], sigdigits = 4),
        MaxGFLOPS = round(gflop[1,j,i], sigdigits = 4)
      )
      last_perfs[i+1] = (libs[i], gflops)
    end
    ProgressMeter.next!(p; showvalues = last_perfs)
    if isodd(_j)
      discard_first = false
    end
  end
  BenchmarkTools.DEFAULT_PARAMETERS.seconds = benchtime # restore previous state
  BenchmarkResult{T}(libs, sizes, gflop, times, threaded)
end
