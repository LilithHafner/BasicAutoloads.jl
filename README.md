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
    import BasicAutoloads
    BasicAutoloads.register_autoloads([
        ["@b", "@be"]            => :(using Chairmarks),
        ["@benchmark"]           => :(using BenchmarkTools),
        ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
        "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
                                    :(using Test),
        ["pager"]                => :(using TerminalPager),
        ["cowsay"]               => :(cowsay(x) = println("Cow: \"$x\"")),
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

---

## API design decisions

Accept a very narrow type signature to force folks to always use the same approach so that
features are inherently discoverable. You are certian to know you can X if you are forced
to do so all the time for X in
  - provide arbitrary exprs
  - provide multiple triggers for a single expr
  - provide macro names as strings instead of symbols

Trivial extensions that I opted not to do
  - Triggers are scalar or iterables of symbols or strings
  - Expres are symbols which expand to :(using Sym)

Simple, but nontrivial extensions
  - Regex as trigger
  - Function as trigger
  - Function (that possibly runs multiple times) as expr
