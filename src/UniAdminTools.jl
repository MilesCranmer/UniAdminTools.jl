module UniAdminTools

include("projalloc.jl")
include("mergescore.jl")

using Reexport: @reexport
@reexport using .ProjAlloc: optimize_project_allocations, projalloc
@reexport using .MergeScore: estimated_merged_scores, mergescore

end
