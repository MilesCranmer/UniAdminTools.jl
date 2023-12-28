using UniAdminTools
using Test
using Aqua

@testset "UniAdminTools.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(UniAdminTools)
    end
    # Write your tests here.
end
