using BLASBenchmarksCPU
using Documenter

makedocs(;
    modules=[BLASBenchmarksCPU],
    authors="Chris Elrod <elrodc@gmail.com> and contributors",
    repo="https://github.com/chriselrod/BLASBenchmarksCPU.jl/blob/{commit}{path}#L{line}",
    sitename="BLASBenchmarksCPU.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chriselrod.github.io/BLASBenchmarksCPU.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Usage" => "usage.md",
        "Turbo" => "turbo.md",
        "Memory Required for Large Matrices" => "memory-required.md",
        "Public API" => "public-api.md",
        "Internals (Private)" => "internals.md",
    ],
    strict=true,
)

deploydocs(;
    repo="github.com/chriselrod/BLASBenchmarksCPU.jl",
)
