const ValBool = Union{Val{true}, Val{false}}

function foreach_thread(f, xs, rest...)
    tasks = Task[]
    i = 0
    for args in zip(xs, rest...)
        task = @task f(args...)
        task.sticky = false
        tid = i % Threads.nthreads()
        ccall(:jl_set_task_tid, Cvoid, (Any, Cint), task, tid)
        schedule(task)
        push!(tasks, task)
        i += 1
    end
    foreach(wait, tasks)
end
