using PkgBenchmark
results = readresults(joinpath(@__DIR__, "results.json"))
export_markdown(joinpath(@__DIR__, "results.md"), results)
