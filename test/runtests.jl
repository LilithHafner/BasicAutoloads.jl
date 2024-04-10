using BasicAutoloads
using Test
using Aqua

@testset "BasicAutoloads.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(BasicAutoloads)
    end
    # Write your tests here.
end
