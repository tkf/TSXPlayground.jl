using BenchmarkTools
using Logging
using TSXPlaygroundBenchmarks: BenchRandomIncrements
using TerminalLoggers

global_logger(TerminalLogger())

let path = get(ARGS, 1, joinpath(@__DIR__, "build", "results.json"))
    mkpath(dirname(path))
    open(versioninfo, joinpath(dirname(path), "versioninfo.txt"), write = true)
    @info "Start benchmarks. Result will be saved to: $path"
    @info "Loading benchmarks..."
    ntasks_list = 2 .^ (0:floor(Int, log2(Threads.nthreads())))
    if ntasks_list[end] !== Threads.nthreads()
        push!(ntasks_list, Threads.nthreads())
    end
    suite = BenchRandomIncrements.setup(
        # ntasks_list = 1:Threads.nthreads(),
        ntasks_list = ntasks_list,
        # include_tsx_static = false,
        nbatches_list = [100],
        ncounters_list = 2 .^ (15:2:25),
    )
    @info "Running benchmarks..."
    results = run(suite; verbose = true)
    @info "Saving benchmarks to $path..."
    BenchmarkTools.save(path, results)
    @info "Saving benchmarks to $path...DONE"
end
