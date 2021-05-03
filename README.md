# TSXPlayground: Playing with hardware transactional memory in Julia

This package contains some code for playing with Intel Transactional
Synchronization Extensions (TSX) in Julia.

## Benchmark: Random increments

A few strategies for parallelizing the following code (which is used as the
baseline for computing the speedup) are benchmarked:

```julia
function serial_random_increments!(counters, indices)
    for i in indices
        @inbounds counters[i] += 1
    end
end
```

See [`src/random_increments.jl`](src/random_increments.jl) for the
implementations and [`notes/random_increments`](notes/random_increments) for how
the benchmarks are run.  The data and a few more plots can be found at [this
gist](https://gist.github.com/tkf/638e269dba1ac267baf2622624726818).

![Benchmark result](https://gist.githubusercontent.com/tkf/638e269dba1ac267baf2622624726818/raw/f0ace44b7a764ee52ebd3a551834c27963d63b4d/plt_speedup.png)

_Implementations_ (rows):

* `atomics`: using relaxed (LLVM's monotonic) atomic add instruction
* `tsx_adaptive`: TSX with adaptive transaction size
* `tsx_static`: TSX with static transaction size

_Problems_ (columns):

* `cluster`: 50 consecutive `indices` ("cluster") points to nearby elements in
  `counter`.  The beggining of each cluster is a uniformly random position in
  `counters`.  (This is similar to the linear probing access pattern in open
  addressing hash table.)
* `uniform`: `indices` are drawn from a uniformly random distribution on
  the `counters` indices; i.e., `indices = rand(1:length(counters), nindices)`.

_#Tasks_ (X axis): The number of parallel tasks (`Threads.@spawn`) that are
incrementing `counters`.

_speedup_ (Y axis): _Tₛ / Tₚ_ where _Tₛ_ is the time for the serial
implementation and _Tₚ_ is the time for the parallel implementation.

_Density_ (color): A benchmark parameter `length(indices) / length(counters)`
that controlls the contention and the cache misses.  In this benchmark,
`length(indices)` is fixed to `2^20` and `length(counters)` is varied between
`2^15` and `2^25`.

**Remarks**

* TSX with a single task does not have a large slow down (except for
  `tsx_adaptive` with high density; maybe the adaptive algorithm can be
  improved?); i.e., the overhead of the base case is small. On the other hand,
  atomics-based implementation starts with _speedup < 1_ and requires several
  parallel tasks to gain some advantage over the serial implementation.

* The overhead of the atomics-based implementation is more visible in the
  _cluster_ problem (left column) where the program can benefit from the memory
  locality.

  * The absolute times of the _cluster_ problem are smaller than the _uniform_
    problem.  This is not visible in the speedup plot since the serial
    implementation is faster as well in this case.

* As expected, there is a slow down with contention (around _Density > 1_).
  However, TSX can regain the speedups even in this case more rapidly than
  atomics.

## How to use

As of Julia 1.7-DEV, it looks like the simplest way to use TSX is to apply a
simple patch to `julia` itself.  See [`julia.patch`](julia.patch).
