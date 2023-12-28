module UniAdminTools

include("project_allocations.jl")
include("combining_sparse_scores.jl")

using Reexport: @reexport
@reexport using .ProjAlloc: optimize_project_allocations, projalloc
@reexport using .MergeScore: estimated_merged_scores

end
