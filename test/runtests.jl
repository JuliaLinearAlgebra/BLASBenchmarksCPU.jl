using BLASBenchmarksCPU
using Test

import InteractiveUtils
import VectorizationBase

include("test-suite-preamble.jl")

@info("VectorizationBase.num_cores() is $(VectorizationBase.num_cores())")

include("main.jl")
