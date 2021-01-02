
function pick_suffix(desc = "")
    suffix = if VectorizationBase.AVX512F
        "AVX512"
    elseif VectorizationBase.AVX2
        "AVX2"
    elseif VectorizationBase.REGISTER_SIZE == 32
        "AVX"
    else
        "REGSIZE$(PaddedMatrices.VectorizationBase.REGISTER_SIZE)"
    end
    if desc != ""
        suffix *= '_' * desc
    end
    "$(Sys.CPU_NAME)_$suffix"
end

function plot(
    br::BenchmarkResult{T};
    desc = "", logscale::Bool = true,
    width = 1200, height = 600
) where {T}
    df = br.df
    plt = if logscale
        df |> @vlplot(
            :line, color = :Library,
            x = {:Size, scale={type=:log}}, y = {:GFLOPS},
            width = width, height = height
        )
    else
        df |> @vlplot(
            :line, color = :Library,
            x = {:Size}, y = {:GFLOPS},
            width = width, height = height
        )
    end
    l, u = extrema(df.Size)
    if logscale
        desc *= "_logscale"
    end
    desc = (br.threaded ? "_multithreaded" : "_singlethreaded") * desc
    suffix = pick_suffix(desc)
    save(joinpath(pkgdir(BLASBenchmarks), "docs/src/assets/gemm_$(string(T))_$(l)_$(u)_$(suffix).svg"), plt)
    save(joinpath(pkgdir(BLASBenchmarks), "docs/src/assets/gemm_$(string(T))_$(l)_$(u)_$(suffix).png"), plt)
end

