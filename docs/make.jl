using BLASBenchmarks
using Documenter

makedocs(;
    modules=[BLASBenchmarks],
    authors="Chris Elrod <elrodc@gmail.com> and contributors",
    repo="https://github.com/chriselrod/BLASBenchmarks.jl/blob/{commit}{path}#L{line}",
    sitename="BLASBenchmarks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chriselrod.github.io/BLASBenchmarks.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Usage" => "usage.md",
        "Public API" => "public-api.md",
        "Internals (Private)" => "internals.md",
    ],
    strict=true,
)

deploydocs(;
    repo="github.com/chriselrod/BLASBenchmarks.jl",
)
