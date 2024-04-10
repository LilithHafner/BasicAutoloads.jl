using BasicAutoloads
using Test
using Aqua

@testset "BasicAutoloads.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(BasicAutoloads, deps_compat=false)
        Aqua.test_deps_compat(BasicAutoloads, check_extras=false)
    end

    @testset "Does not throw" begin
        register_autoloads([
            ["@b", "@be"]            => :(using Chairmarks),
            ["@benchmark"]           => :(using BenchmarkTools),
            ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
            "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
                                        :(using Test),
            ["@about"]               => :(using About; macro about(x) Expr(:call, About.about, x) end),
        ])
    end
end
