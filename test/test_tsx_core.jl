module TestTSXCore

using Test
using TSXPlayground.TSX

const NTRIES = 1000

function first_transacted(f)
    local result
    for _ in 1:NTRIES
        result = f()
        result.transacted && break
    end
    return result
end

function trivial()
    transacted = false
    if (code = xbegin()) == XBEGIN_STARTED
        transacted = true
        xend()
    end
    return (; transacted, code)
end

function simple_abort()
    transacted = false
    if (code = xbegin()) == XBEGIN_STARTED
        transacted = true
        @xabort 42
        xend()
    end
    return (; transacted, code)
end

function check_xtest()
    transacted = false
    outside = xtest()
    inside = 0
    if (code = xbegin()) == XBEGIN_STARTED
        transacted = true
        inside = xtest()
        xend()
    end
    return (; transacted, code, outside, inside)
end

@inline function tryinc!(counter)
    transacted = false
    if (code = xbegin()) == XBEGIN_STARTED
        counter[] += 1
        transacted = true
        xend()
    end
    return (; transacted, code)
end

function check_conflict!(counter, me, other, limit)
    local result
    n = 0
    t = 0
    c = 0
    allcode = Int32(0)
    ok = false
    for _ in 1:limit
        result = tryinc!(counter)
        n += 1
        t += result.transacted
        c += TSX.is_conflict(result.code)
        allcode |= result.code
        if c > 0
            me[] = ok = true
        end
        ok && other[] && break
    end
    return (; n, t, c, allcode, result...)
end

function check_conflict(limit = 1000_0000)
    padded = Vector{Int}(undef, 128)
    counter = view(padded, 64)
    counter[] = 0
    done1 = Threads.Atomic{Bool}(false)
    done2 = Threads.Atomic{Bool}(false)

    local r1
    tid = mod1(Threads.threadid() + 1, Threads.nthreads())
    task = @task begin
        r1 = check_conflict!(counter, done1, done2, limit)
    end
    task.sticky = false
    ccall(:jl_set_task_tid, Cvoid, (Any, Cint), task, tid - 1)
    schedule(task)

    r2 = check_conflict!(counter, done2, done1, limit)
    wait(task)

    return (; limit, r1, r2, counter = counter[])
end

function test_conflict()
    result = check_conflict()
    @debug "`check_conflict()`" result
    @test TSX.is_conflict(result.r1.allcode) && TSX.is_conflict(result.r2.allcode)
    @test result.r1.t + result.r2.t == result.counter
    return result
end

@testset "trivial" begin
    result = first_transacted(trivial)
    @test result.transacted == true
end

@testset "simple_abort" begin
    local result
    for _ in 1:NTRIES
        result = simple_abort()
        TSX.is_explicit(result.code) && break
    end
    @test TSX.is_explicit(result.code)
    @test result.transacted == false
    @test xabort_code(result.code) == 42
end

@testset "check_xtest" begin
    result = first_transacted(check_xtest)
    @test result.transacted == true
    @test result.outside == 0
    @test result.inside != 0
end

@testset "check_conflict" begin
    if Threads.nthreads() > 1
        test_conflict()
    end
end

end  # module
