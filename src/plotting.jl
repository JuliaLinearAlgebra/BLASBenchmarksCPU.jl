
####################################################################################################
####################################### Colors #####################################################
####################################################################################################

const LIBRARIES = [:Octavian, :MKL, :OpenBLAS, :blis, :Tullio, :Gaius, :Generic];
"""
Defines the mapping between libraries and colors
"""# #0071c5 == Intel Blue
const COLOR_MAP = Dict(zip(LIBRARIES, distinguishable_colors(length(LIBRARIES), [RGB(1,0,0), colorant"#0071c5"])));
getcolor(l::Symbol) = COLOR_MAP[l]
for (alias,ref) ∈ [(:BLIS,:blis),(:generic,:Generic),(:GENERIC,:Generic)]
    COLOR_MAP[alias] = COLOR_MAP[ref]
end


####################################################################################################
####################################### Plots ######################################################
####################################################################################################


function pick_suffix(desc = "")
    suffix = if VectorizationBase.has_feature("x86_64_avx512f")
        "AVX512"
    elseif VectorizationBase.has_feature("x86_64_avx2")
        "AVX2"
    elseif VectorizationBase.has_feature("x86_64_avx")
        "AVX"
    else
        "REGSIZE$(VectorizationBase.register_size())"
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
    l, u = extrema(br.sizes)
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
function Gadfly.plot(br::BenchmarkResult{T}; kwargs...) where {T}
    _plot(br; kwargs...)
    return nothing
end
roundint(x) = round(Int,x)
# `_plot` is just like `plot`, except _plot returns the filenames
function _plot(
    br::BenchmarkResult{T};
    desc::AbstractString = "",
    logscale::Bool = true,
    width = 12inch,
    height = 8inch,
    plot_directory::AbstractString = default_plot_directory(),
    plot_filename::AbstractString = default_plot_filename(br; desc = desc, logscale = logscale),
    file_extensions = ["svg", "png"],
) where {T}
    colors = getcolor.(br.libraries);
    libraries = string.(br.libraries)
    xscale = logscale ? Scale.x_log10(labels=string ∘ roundint ∘ exp10) : Scale.x_continuous
    # xscale = logscale ? Scale.x_log10 : Scale.x_continuous
    plt = plot(
        Gadfly.Guide.manual_color_key("Libraries", libraries, colors),
        Guide.xlabel("Size"), Guide.ylabel("GFLOPS"), xscale
    )
    for i ∈ eachindex(libraries)
        l = layer(
            x = br.sizes, y = br.gflops[:,i],
            Geom.line, Theme(default_color = colors[i])
        )
        push!(plt, l)
    end
    mkpath(plot_directory)
    _filenames = String[]
    extension_dict = Dict("svg" => SVG, "png" => PNG, "pdf" => PDF, "ps" => PS)
    for ext in file_extensions
        _filename = joinpath(plot_directory, "$(plot_filename).$(ext)")
        draw(extension_dict[ext](_filename, width, height), plt)
        push!(_filenames, _filename)
    end
    return _filenames
end
