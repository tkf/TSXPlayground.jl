.PHONY: test benchmark

test:
	$(JULIA) --project --check-bounds=yes test/runtests.jl

BENCHMARK_PROJECT = benchmark

benchmark: benchmark/results.json benchmark/results.md

benchmark/results.json: $(BENCHMARK_PROJECT)/Manifest.toml
	$(JULIA) --project=$(BENCHMARK_PROJECT) benchmark/runbenchmarks.jl

benchmark/results.md: benchmark/results.json
	$(JULIA) --project=$(BENCHMARK_PROJECT) -t1 benchmark/export_markdown.jl

$(BENCHMARK_PROJECT)/Manifest.toml:
	$(JULIA) --project=$(BENCHMARK_PROJECT) -t1 -e 'using Pkg; \
	Pkg.develop(path="."); \
	Pkg.develop(path="benchmark/TSXPlaygroundBenchmarks"); \
	Pkg.instantiate()'

Make.user:
	ln -s Make.user.tkf Make.user

-include Make.user
