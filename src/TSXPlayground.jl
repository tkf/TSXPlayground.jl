module TSXPlayground

using Random

include("utils.jl")
include("TSX.jl")
include("UnsafeAtomics.jl")

using .TSX
using .UnsafeAtomics: unordered, monotonic, acquire, release, acq_rel, seq_cst

include("random_increments.jl")

end
