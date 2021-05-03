.PHONY: clean benchmark

JULIA_CMD = $(JULIA) --project=build

analysis: build/analysis.jl benchmark

benchmark: results.json build/lscpu.txt

build/analysis.jl: analysis.jl build/results.json
	cp $< $@.tmp
	$(JULIA_CMD) -t1 $@.tmp
	mv $@.tmp $@

results.json: build/results.json
	rm -f results.json
	cp $< $@

build/results.json: build/Manifest.toml
	$(JULIA_CMD) runbenchmarks.jl

build/Manifest.toml: Project.toml
	rm -fv build/Project.toml
	$(JULIA_CMD) -t1 -e 'using Pkg; \
	Pkg.develop(path="../../"); \
	Pkg.develop(path="../../benchmark/TSXPlaygroundBenchmarks")'
	cp $< build/Project.toml
	$(JULIA_CMD) -t1 -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'

build/lscpu.txt:
	lscpu > $@

BACKUPDIR = backup/$(shell date +%Y/%m/%d-%H%M%S/)

$(BACKUPDIR):
	@mkdir -p $@

clean: $(BACKUPDIR)
	mv build $<

Make.user:
	ln -sf Make.user.tkf Make.user

-include Make.user
