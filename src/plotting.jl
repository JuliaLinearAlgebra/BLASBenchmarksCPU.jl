
function pick_suffix(desc = "")
    suffix = if VectorizationBase.AVX512F
        "AVX512"
    elseif VectorizationBase.AVX2
        "AVX2"
    elseif VectorizationBase.REGISTER_SIZE == 32
        "AVX"
    else
        "REGSIZE$(VectorizationBase.REGISTER_SIZE)"
    end
    if desc != ""
        suffix *= '_' * desc
    end
    "$(Sys.CPU_NAME)_$suffix"
end

function _pkgdir()
    return dirname(dirname(@__FILE__))
end

"""
    default_plot_directory()
"""
function default_plot_directory()
    return joinpath(_pkgdir(), "docs", "src", "assets")
end

"""
    default_plot_filename(br::BenchmarkResult;
                          desc,
                          logscale)
"""
function default_plot_filename(br::BenchmarkResult{T};
                               desc::AbstractString,
                               logscale::Bool) where {T}
    df = br.df
    l, u = extrema(df.Size)
    if logscale
        desc *= "_logscale"
    end
    desc = (br.threaded ? "_multithreaded" : "_singlethreaded") * desc
    suffix = pick_suffix(desc)
    return "gemm_$(string(T))_$(l)_$(u)_$(suffix)"
end

"""
    plot(br::BenchmarkResult;
         desc = "",
         logscale = true,
         width = 1200,
         height = 600,
         plot_directory = default_plot_directory(),
         plot_filename = default_plot_filename(br; desc = desc, logscale = logscale),
         file_extensions = ["svg", "png"])
"""
function plot(br::BenchmarkResult{T}; kwargs...) where {T}
    _plot(br; kwargs...)
    return nothing
end

# `_plot` is just like `plot`, except _plot returns the filenames
function _plot(
    br::BenchmarkResult{T};
    desc::AbstractString = "",
    logscale::Bool = true,
    width::Real = 1200,
    height::Real = 600,
    plot_directory::AbstractString = default_plot_directory(),
    plot_filename::AbstractString = default_plot_filename(br; desc = desc, logscale = logscale),
    file_extensions = ["svg", "png"],
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
    mkpath(plot_directory)
    for ext in file_extensions
        save(joinpath(plot_directory, "$(plot_filename).$(ext)"), plt)
    end
    return foo1, foo2
end
