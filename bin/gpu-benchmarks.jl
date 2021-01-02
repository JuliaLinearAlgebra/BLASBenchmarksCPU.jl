using BenchmarkTools
using CUDA
using KernelAbstractions
using LinearAlgebra
using Plotly
using Plots
using ProgressMeter
using Test
using Tullio

Plots.plotly()

CUDA.has_cuda_gpu() || throw(ErrorException("No CUDA GPU is available"))

CUDA.allowscalar(false)

@inline function matmul_tullio!(C::CuArray, A::CuArray, B::CuArray)
    @tullio C[i,k] = A[i,j] * B[j,k] threads=false cuda=256
    return nothing
end

@inline function matmul_cublas!(C::CuArray, A::CuArray, B::CuArray)
    LinearAlgebra.mul!(C, A, B)
    return nothing
end

@kernel function _kernel_ka!(C, A, B)
    i, j = @index(Global, NTuple)
    Cij = zero(eltype(C))
    for k = 1:size(A)[2]
        Cij += A[i,k] * B[k, j]
    end
    C[i, j] = Cij
end

@inline function matmul_ka!(C::CuArray, A::CuArray, B::CuArray)
    kernel! = _kernel_ka!(CUDADevice(), 256)
    ev = kernel!(C, A, B; ndrange=size(C))
    wait(ev)
    return nothing
end

Ts = [Float64, Float32]
ns = 2:500
nanoseconds_tullio = Dict()
nanoseconds_cublas = Dict()
nanoseconds_ka = Dict()
for T in Ts
    nanoseconds_tullio[T] = Vector{Float64}(undef, length(ns))
    nanoseconds_cublas[T] = Vector{Float64}(undef, length(ns))
    nanoseconds_ka[T] = Vector{Float64}(undef, length(ns))
    progress_bar = false
    verbose = true
    if progress_bar
        dt = 1
    else
        dt = Inf
    end
    @showprogress dt "$(T): " for (i, n) in enumerate(ns)
        GC.gc()
        CUDA.reclaim()
        A = CuArray(rand(T, n, n));
        B = CuArray(rand(T, n, n));
        C1 = CuArray(zeros(T, n, n));
        C2 = CuArray(zeros(T, n, n));
        C3 = CuArray(zeros(T, n, n));
        matmul_tullio!(C1, A, B)
        matmul_cublas!(C2, A, B)
        matmul_ka!(C3, A, B)
        @test C1 ≈ A * B
        @test C2 ≈ A * B
        @test C3 ≈ A * B
        trial_tullio = @benchmark matmul_tullio!($C1, $A, $B)
        trial_cublas = @benchmark matmul_cublas!($C2, $A, $B)
        trial_ka     = @benchmark matmul_ka!($C2, $A, $B)
        nanoseconds_tullio[T][i] = time(minimum(trial_tullio))
        nanoseconds_cublas[T][i] = time(minimum(trial_cublas))
        nanoseconds_ka[T][i]     = time(minimum(trial_ka))
        if verbose
            @show T n nanoseconds_tullio[T][i] nanoseconds_cublas[T][i] nanoseconds_ka[T][i]
            if !progress_bar
                flush(stdout)
                flush(stderr)
            end
        end
    end
end

plots = Dict()
plots_loglog = Dict()
for T in Ts
    p1 = Plots.plot(ns, nanoseconds_tullio[T]; label = "Tullio", title = "$(T) matrix-matrix multiplication");
    Plots.plot!(p1, ns, nanoseconds_cublas[T]; label = "cuBLAS");
    Plots.plot!(p1, ns, nanoseconds_ka[T];     label = "KA");
    Plots.xlabel!(p1, "Matrix size");
    Plots.ylabel!(p1, "Runtime (nanoseconds)");
    plots[T] = p1;

    p2 = Plots.plot(log.(ns), log.(nanoseconds_tullio[T]); label = "Tullio", title = "$(T) matrix-matrix multiplication");
    Plots.plot!(p2, log.(ns), log.(nanoseconds_cublas[T]); label = "cuBLAS");
    Plots.plot!(p2, log.(ns), log.(nanoseconds_ka[T]);     label = "KA");
    Plots.xlabel!(p2, "Log matrix size");
    Plots.ylabel!(p2, "Log runtime (nanoseconds)");
    plots_loglog[T] = p2;
end
for T in Ts
    plot_filename = string(T, ".svg")
    @info "Saving plot to $(plot_filename)"
    p1 = plots[T]
    Plots.savefig(p1, plot_filename)

    plot_loglog_filename = string(T, "_loglog.svg")
    @info "Saving log-log plot to $(plot_loglog_filename)"
    p2 = plots_loglog[T]
    Plots.savefig(p2, plot_loglog_filename)
end
