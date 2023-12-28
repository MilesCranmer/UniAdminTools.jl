module UniAdminTools

include("project_allocations.jl")

using Reexport: @reexport
@reexport using .ProjAlloc: optimize_project_allocations, projalloc

end
