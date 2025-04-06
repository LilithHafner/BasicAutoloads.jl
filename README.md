# BasicAutoloads

[![Build Status](https://github.com/LilithHafner/BasicAutoloads.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/BasicAutoloads.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/BasicAutoloads.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/BasicAutoloads.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/B/BasicAutoloads.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/B/BasicAutoloads.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

BasicAutoloads lets you say "whenever I type this in the REPL, run that for me". It's great
for automatically loading interactive tools.

For example, put this in your startup.jl

```julia
if isinteractive()
    using BasicAutoloads
    register_autoloads([
        ["@b", "@be"]            => :(using Chairmarks),
        ["@benchmark"]           => :(using BenchmarkTools),
        ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
        "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
                                    :(using Test),
        ["about, @about"]        => :(using About; macro about(x) Expr(:call, About.about, x) end),
        ["pager"]                => :(using TerminalPager),
    ])
end
```

Add `BasicAutoloads` and any packages you want to automatically load to your default
environment, and then enjoy the benefits at the REPL:

```julia
julia> Test
ERROR: UndefVarError: `Test` not defined in `Main`
Suggestion: check for spelling errors or missing imports.

julia> @test 1+1 == 2 # Test is automatically loaded here
Test Passed

julia> Test
Test
```

Scripts and such will still need to explicitly load their deps.

For more details, see the [docstring of `register_autoloads`](https://github.com/LilithHafner/BasicAutoloads.jl/blob/main/src/BasicAutoloads.jl#L6)
