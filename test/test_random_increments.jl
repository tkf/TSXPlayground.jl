module TestRandomIncrements

using Test
using TSXPlayground:
    parallel_random_increments!,
    random_increments_problem_clusters,
    random_increments_problem_uniform,
    serial_random_increments!

ncounters = 2^20
nindices = 2^5

@testset "$label" for (label, (counters, indices)) in [
    ("uniform", random_increments_problem_uniform(ncounters, nindices)),
    ("cluster", random_increments_problem_clusters(ncounters, nindices, 5)),
]
    counters_seq = zero(counters)
    serial_random_increments!(counters_seq, indices)
    @testset for ntasks in 1:Threads.nthreads()
        counters_atomic = zero(counters)
        counters_tsx = zero(counters)
        parallel_random_increments!(counters_atomic, indices, ntasks)
        parallel_random_increments!(counters_tsx, indices, ntasks, Val(true), 10, 4)
        @test counters_atomic == counters_seq
        @test counters_tsx == counters_seq
    end
end

end  # module
