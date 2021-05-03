using BenchmarkTools
using DataFrames
using VegaLite

results = only(BenchmarkTools.load(joinpath(@__DIR__, "results.json")))

function parse_problem_label(label)
    m = match(
        r"""
        ^([^-]+)
        (?:- (?:clustersize=([^-]+)))?
        - (?:ncounters=([^-]+))
        - (?:nindices=([^-]+))
        """x,
        label,
    )
    @assert m !== nothing
    problem = Symbol(m[1])
    if m[2] === nothing
        clustersize = missing
    else
        clustersize = parse(Int, m[2])
    end
    ncounters = parse(Int, m[3])
    nindices = parse(Int, m[4])
    return (; problem, clustersize, ncounters, nindices)
end
@assert parse_problem_label("uniform-ncounters=1-nindices=2") ===
        (problem = :uniform, clustersize = missing, ncounters = 1, nindices = 2)
@assert parse_problem_label("cluster-clustersize=0-ncounters=1-nindices=2") ===
        (problem = :cluster, clustersize = 0, ncounters = 1, nindices = 2)

function parsenamed(T, prefix, str)
    @assert startswith(str, prefix)
    return parse(T, str[length(prefix)+1:end])
end

begin
    rawtable = map(leaves(results)) do (labels, trial)
        plabel = parse_problem_label(labels[1])
        ntries = nbatches = missing
        if labels[2] == "seq"
            impl = :seq
            ntasks = 1
        else
            ntasks = parsenamed(Int, "ntasks=", labels[2])
            impl = Symbol(labels[3])
            if impl === :tsx_static
                ntries = parsenamed(Int, "ntries=", labels[4])
                nbatches = parsenamed(Int, "nbatches=", labels[5])
            end
        end
        return (; plabel..., ntasks, impl, ntries, nbatches, trial)
    end

    rawdf = DataFrame(rawtable)
end

begin
    df1 = select(rawdf, Not(:trial))
    df1[!, :time] = map(trial -> minimum(trial).time ./ 1000_000, rawdf.trial)
    df1
end

function saveplot(; plt_...)
    name, plt = only(plt_)
    save(joinpath(@__DIR__, "$name.png"), plt)
    save(joinpath(@__DIR__, "$name.vegalite"), plt)
end

config = let
    fontconfig = @vlfrag(labelFontSize = 20, titleFontSize = 20)
    @vlfrag(
        axis = fontconfig,
        legend = fontconfig,
        header = fontconfig,
        title = fontconfig,
        # mark = ...
    )
end

plt_raw = @vlplot(
    mark = {type = :line, point = true},
    x = {
        field = :ncounters,
        title = "length(counters)",
        axis = {format = "e"},
        scale = {type = :log},
        type = :quantitative,
    },
    y = {field = :time, title = "time [ms]", type = :quantitative},
    color = {field = :impl, title = ""},
    column = :problem,
    row = {field = :ntasks, title = "Number of parallel tasks"},
    data = df1,
    width = 200,
    height = 100,
    config = config,
)
saveplot(; plt_raw)

function add_density!(df)
    df[!, :density_value] = df.nindices ./ df.ncounters
    df[!, :Density] = map(df.nindices ./ df.ncounters) do d
        if d >= 1
            string(round(Int, d))
        else
            "1/$(round(Int, 1/d))"
        end
    end
    return df
end

let idx_seq = df1.impl .== :seq
    cols = [:problem, :ncounters, :nindices]
    global df_seq = df1[idx_seq, [cols..., :time]]
    rename!(df_seq, :time => :time_seq)
    global df_speedup =
        leftjoin(df1[.!idx_seq, :], df_seq, on = cols, validate = (false, true))
    df_speedup[!, :speedup] = df_speedup.time_seq ./ df_speedup.time
    add_density!(df_speedup)
    df_speedup
end

plt_speedup = @vlplot(
    facet = {
        column = {field = :problem, title = "Problems"},
        row = {field = :impl, title = "Implementations"},
    },
    spec = {
        layer = [
            {mark = {type = :rule}, encoding = {y = {datum = 1}}},
            {
                mark = {type = :line, point = true},
                encoding = {
                    x = {field = :ntasks, type = :quantitative, title = "#Tasks"},
                    y = {field = :speedup, type = :quantitative},
                    color = {
                        field = :Density,
                        type = :ordinal,
                        sort = {field = :density_value},
                        scale = {scheme = :inferno}
                    },
                },
            },
        ],
        width = 120,
        height = 120,
    },
    data = df_speedup,
    config = config,
)
saveplot(; plt_speedup)

let idx_uniform = df1.problem .== :uniform
    cols = [:impl, :ncounters, :nindices, :ntasks]
    global df_uniform = df1[idx_uniform, [cols..., :time]]
    rename!(df_uniform, :time => :time_uniform)
    global df_vs_uniform =
        leftjoin(df1[.!idx_uniform, :], df_uniform, on = cols, validate = (false, true))
    df_vs_uniform[!, :relative_time] = df_vs_uniform.time ./ df_vs_uniform.time_uniform
    add_density!(df_vs_uniform)
    df_vs_uniform
end

plt_vs_uniform_on_ntasks = @vlplot(
    facet = {
        column = {field = :problem, title = "Problems"},
        row = {field = :impl, title = "Implementations"},
    },
    spec = {
        layer = [
            {mark = {type = :rule}, encoding = {y = {datum = 1}}},
            {
                mark = {type = :line, point = true},
                encoding = {
                    x = {field = :ntasks, type = :quantitative, title = "#Tasks"},
                    y = {field = :relative_time, type = :quantitative},
                    color = {
                        field = :Density,
                        type = :ordinal,
                        sort = {field = :density_value},
                    },
                },
            },
        ],
        width = 120,
        height = 120,
    },
    data = df_vs_uniform,
    config = config,
)

plt_vs_uniform = @vlplot(
    facet = {
        column = {field = :problem, title = "Problems"},
        row = {field = :impl, title = "Implementations"},
    },
    spec = {
        layer = [
            {mark = {type = :rule}, encoding = {y = {datum = 1}}},
            {
                mark = {type = :line, point = true},
                encoding = {
                    x = {
                        field = :Density,
                        type = :ordinal,
                        sort = {field = :density_value},
                    },
                    y = {field = :relative_time, type = :quantitative},
                    color = {
                        field = :ntasks,
                        type = :ordinal,
                        title = "#Tasks",
                        scale = {scheme = :viridis},
                    },
                },
            },
        ],
        width = 120,
        height = 120,
    },
    data = df_vs_uniform,
    config = config,
)
saveplot(; plt_vs_uniform)
