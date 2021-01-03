module BLASBenchmarks

# BLAS libs (& Libdl)
using MKL_jll, OpenBLAS_jll, Libdl#, blis_jll
# Julia BLAS
using PaddedMatrices, Octavian, Gaius, Tullio

# utils: LoopVectorization for Tullio.jl, VectorizationBase for info
using LoopVectorization, VectorizationBase
using VectorizationBase: NUM_CORES, align

# Adjoint
using LinearAlgebra

# Utils
using BenchmarkTools, ProgressMeter

# Plotting & presenting results
using VegaLite, DataFrames


export runbench, logspace, plot,
    gemmmkl!, mkl_set_num_threads,
    gemmopenblas!, openblas_set_num_threads

# set threads
const libMKL = MKL_jll.libmkl_rt # more convenient name
function mkl_set_num_threads(N::Integer)
    ccall((:MKL_Set_Num_Threads,libMKL), Cvoid, (Int32,), N % Int32)
end
const libOPENBLAS = OpenBLAS_jll.libopenblas # more convenient name
function openblas_set_num_threads(N::Integer)
    ccall((:openblas_set_num_threads64_,OpenBLAS_jll.libopenblas), Cvoid, (Int64,), N)
end

include("ccallblas.jl")
include("benchconfig.jl")
include("runbenchmark.jl")
include("plotting.jl")

function __init__()
    mkl_set_num_threads(VectorizationBase.NUM_CORES)
    openblas_set_num_threads(VectorizationBase.NUM_CORES)
end

end
