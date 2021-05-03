module BenchRandomIncrements

using BenchmarkTools
using TSXPlayground:
    parallel_random_increments!,
    parallel_random_increments_adaptive!,
    random_increments_problem_clusters,
    random_increments_problem_uniform,
    serial_random_increments!

function default_ntasks_list()
    ntasks_list = [Threads.nthreads()]
    if Threads.nthreads() > 2
        pushfirst!(ntasks_list, 2)
    end
    return ntasks_list
end

function default_problems(;
    ncounters_list = [2^30],
    nindices_list = [2^20],
    clustersize_list = [50],
    include_uniform = true,
    include_clusters = true,
)
    problems = []
    for ncounters in ncounters_list, nindices in nindices_list
        label_suffix = "ncounters=$ncounters-nindices=$nindices"
        if include_uniform
            p = () -> random_increments_problem_uniform(ncounters, nindices)
            push!(problems, ("uniform-$label_suffix", p))
        end
        if include_clusters
            for clustersize in clustersize_list
                p = () -> random_increments_problem_clusters(ncounters, nindices, clustersize)
                push!(problems, ("cluster-clustersize=$clustersize-$label_suffix", p))
            end
        end
    end
    return problems
end

const CACHE = Ref{Any}(nothing)

function maybe_cached(f)
    c = CACHE[]
    if c isa Tuple{Any,Any} && c[1] === f
        return c[2]
    end
    t = @elapsed y = f()
    if t > 0.5
        CACHE[] = (f, y)
    end
    return y
end

function setup(;
    include_all = true,
    include_seq = include_all,
    include_atomics = include_all,
    include_tsx_static = include_all,
    include_tsx_adaptive = include_all,
    ntries_list = [10],
    nbatches_list = [50, 100],
    ntasks_list = default_ntasks_list(),
    problems = nothing,
    problems_options...,
)
    suite = BenchmarkGroup()

    if problems === nothing
        problems = default_problems(; problems_options...)
    end

    for (label, p) in problems
        s0 = suite[label] = BenchmarkGroup()

        if include_seq
            s0["seq"] = @benchmarkable(
                serial_random_increments!(counters, indices),
                setup = begin
                    counters, indices = maybe_cached($p)
                    fill!(counters, 0)
                end,
            )
        end
        for ntasks in ntasks_list
            s1 = s0["ntasks=$ntasks"] = BenchmarkGroup()
            if include_atomics
                s1["atomics"] = @benchmarkable(
                    parallel_random_increments!(counters, indices, $ntasks),
                    setup = begin
                        counters, indices = maybe_cached($p)
                        fill!(counters, 0)
                    end,
                )
            end
            if include_tsx_static
                s1["tsx_static"] = s2 = BenchmarkGroup()
                for ntries in ntries_list
                    s2["ntries=$ntries"] = s3 = BenchmarkGroup()
                    for nbatches in nbatches_list
                        s3["nbatches=$nbatches"] = @benchmarkable(
                            parallel_random_increments!(
                                counters,
                                indices,
                                $ntasks,
                                Val(true),
                                $nbatches,
                                $ntries,
                            ),
                            setup = begin
                                counters, indices = maybe_cached($p)
                                fill!(counters, 0)
                            end,
                        )
                    end
                end
            end
            if include_tsx_adaptive
                s1["tsx_adaptive"] = @benchmarkable(
                    parallel_random_increments_adaptive!(counters, indices, $ntasks),
                    setup = begin
                        counters, indices = maybe_cached($p)
                        fill!(counters, 0)
                    end,
                )
            end
        end
    end

    return suite
end

function clear()
    CACHE[] = nothing
end

end  # module
