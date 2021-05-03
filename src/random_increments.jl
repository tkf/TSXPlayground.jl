function serial_random_increments!(counters, indices)
    for i in indices
        @inbounds counters[i] += 1
    end
end

random_increments!(counters, indices) =
    random_increments!(counters, indices, Val{false}(), lastindex(indices), -1)

function random_increments!(
    counters,
    indices,
    tsx::ValBool,
    nbatches::Integer,
    ntries::Integer,
)
    k = firstindex(indices)
    batchbound = lastindex(indices) - nbatches
    # nabt = 0
    while k <= batchbound
        if tsx === Val(true)
            for _ in 1:ntries
                code = xbegin()
                if code == XBEGIN_STARTED
                    for _ in 1:nbatches
                        @inbounds counters[indices[k]] += 1
                        k += 1
                    end
                    xend()
                    @goto continue_outer
                end
            end
        end
        # nabt += nbatches

        for _ in 1:nbatches
            i = @inbounds indices[k]
            UnsafeAtomics.add!(pointer(counters, i), one(eltype(counters)), monotonic)
            k += 1
        end

        @label continue_outer
    end

    while k <= lastindex(indices)
        if tsx === Val(true)
            for _ in 1:ntries
                code = xbegin()
                if code == XBEGIN_STARTED
                    @inbounds counters[indices[k]] += 1
                    k += 1
                    xend()
                    @goto continue_outer2
                end
            end
        end
        # nabt += 1

        i = @inbounds indices[k]
        UnsafeAtomics.add!(pointer(counters, i), one(eltype(counters)), monotonic)
        k += 1

        @label continue_outer2
    end

    # @show nabt / length(indices)
end

function random_increments_adaptive!(counters, indices, ntries = 4)
    k = firstindex(indices)
    batchsize = 1
    while true
        k <= lastindex(indices) || return

        kbatch = min(lastindex(indices), k + batchsize - 1)
        for _ in 1:ntries
            code = xbegin()
            if code == XBEGIN_STARTED
                while k <= kbatch
                    @inbounds counters[indices[k]] += 1
                    k += 1
                end
                xend()
                batchsize += 1  # stretch batch on success
                batchsize = max(1, min(batchsize, lastindex(counters) - k + 1))
                @goto continue_outer
            end
        end

        batchsize = max(1, batchsize ÷ 2)  # shrink batch on failure

        i = @inbounds indices[k]
        UnsafeAtomics.add!(pointer(counters, i), one(eltype(counters)), monotonic)
        k += 1

        @label continue_outer
    end
end

function parallel_random_increments!(counters, indices, ntasks, args...)
    chuncked_indices = Iterators.partition(indices, cld(length(indices), ntasks))
    @assert length(chuncked_indices) == ntasks
    foreach_thread(chuncked_indices) do chunk
        random_increments!(counters, chunk, args...)
    end
end

function parallel_random_increments_adaptive!(counters, indices, ntasks, args...)
    chuncked_indices = Iterators.partition(indices, cld(length(indices), ntasks))
    @assert length(chuncked_indices) == ntasks
    foreach_thread(chuncked_indices) do chunk
        random_increments_adaptive!(counters, chunk, args...)
    end
end

function random_increments_problem_uniform(ncounters, nindices)
    counters = zeros(Int, ncounters)
    indices = rand(1:ncounters, nindices)
    return (; counters, indices)
end

function random_increments_problem_clusters(ncounters, nindices, clustersize)
    counters = zeros(Int, ncounters)
    indices = Vector{Int}(undef, cld(nindices, clustersize) * clustersize)
    @assert length(indices) >= nindices
    rand!(@view(indices[1:clustersize:end]), 1:ncounters)
    for i in 2:clustersize
        @view(indices[i:clustersize:end]) .=
            mod1.(@view(indices[i-1:clustersize:end]) .+ 1, ncounters)
    end
    resize!(indices, nindices)
    @assert all(in(eachindex(counters)), indices)
    return (; counters, indices)
end
