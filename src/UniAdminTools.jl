module UniAdminTools

include("project_allocations.jl")

using Reexport: @reexport
@reexport using .ProjectAllocations: optimize_project_allocations

end
