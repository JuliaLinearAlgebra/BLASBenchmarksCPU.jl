using BLASBenchmarks
using Documenter

makedocs(;
    modules=[BLASBenchmarks],
    authors="Chris Elrod <elrodc@gmail.com> and contributors",
    repo="https://github.com/"Chris Elrod"/BLASBenchmarks.jl/blob/{commit}{path}#L{line}",
    sitename="BLASBenchmarks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://"Chris Elrod".github.io/BLASBenchmarks.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/"Chris Elrod"/BLASBenchmarks.jl",
)
