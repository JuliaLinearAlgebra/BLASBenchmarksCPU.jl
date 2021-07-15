module BLASBenchmarksCPU

# BLAS libs (& Libdl)
using MKL_jll, OpenBLAS_jll, blis_jll#, Libdl
# Julia BLAS
using Tullio, Octavian, Gaius

# utils: LoopVectorization for Tullio.jl, VectorizationBase for info
using LoopVectorization, VectorizationBase
using VectorizationBase: num_cores, align
using RecursiveFactorization

using Random

# Adjoint
using LinearAlgebra

# Utils
using BenchmarkTools, ProgressMeter

# Plotting & presenting results
using Cairo
using Fontconfig, Gadfly, Colors, DataFrames

export benchmark_result_type
export benchmark_result_df
export benchmark_result_threaded
export logspace
export plot
export runbench

# BLIS
export gemmblis!
export blis_set_num_threads

# Octavian.jl
export matmul!

# OpenBLAS
export gemmopenblas!
export openblas_set_num_threads

# MKL
export gemmmkl!, gemmmkl_direct!
export mkl_set_num_threads

# set threads
const libMKL = MKL_jll.libmkl_rt # more convenient name
function mkl_set_num_threads(N::Integer)
    ccall((:MKL_Set_Num_Threads,libMKL), Cvoid, (Int32,), N % Int32)
end
const libOPENBLAS = OpenBLAS_jll.libopenblas # more convenient name
function openblas_set_num_threads(N::Integer)
    ccall((:openblas_set_num_threads64_,libOPENBLAS), Cvoid, (Int64,), N)
end

const libBLIS = blis_jll.blis # more convenient name
function blis_set_num_threads(N::Integer)
    ccall((:bli_thread_set_num_threads,libBLIS), Cvoid, (Int32,), N)
end
function blis_get_num_threads(N::Integer)
    ccall((:bli_thread_get_num_threads,libBLIS), Int32, ())
end


include("ccallblas.jl")
include("benchconfig.jl")
include("runbenchmark.jl")
include("plotting.jl")

function __init__()
    mkl_set_num_threads(num_cores())
    openblas_set_num_threads(num_cores())
    blis_set_num_threads(num_cores())
end

end
