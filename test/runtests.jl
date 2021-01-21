using BLASBenchmarksCPU
using Test

import InteractiveUtils
import VectorizationBase

include("test-suite-preamble.jl")

@info("VectorizationBase.NUM_CORES is $(VectorizationBase.NUM_CORES)")

include("main.jl")
