module BasicAutoloads

export register_autoloads

#=
API design decisions:
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
=#

"""
    register_autoloads(autoloads::Vector{Pair{Vector{String}, Expr}})
    register_autoloads([
        [trigger1, trigger2, ...]   => expr1,
        [trigger10, trigger11, ...] => expr2,
        ...
    ])

Register a expressions to be executed when a trigger is found in the REPL's input.

Eech `trigger` must be a `String`. If the `trigger` is found as a symbol (e.g. variable,
function, or macro name) in an input expression to the REPL, the corresponding `expr` is
evaluated. Each `expr` must be an `Expr` and is evaluated with `Main.eval(expr)`. Each
unique `expr`, up to equality, is evaluated at most once.

# Example

```jldoctest
if isinteractive()
    import BasicAutoloads
    BasicAutoloads.register_autoloads([
        ["@b", "@be"]            => :(using Chairmarks),
        ["@benchmark"]           => :(using BenchmarkTools),
        ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
        "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
                                    :(using Test),
        ["@about"]               => :(using About; macro about(x) Expr(:call, About.about, x) end),
    ])
end
```
"""
function register_autoloads(autoloads::Vector{Pair{Vector{String}, Expr}})
    isinteractive() || return
    REPL = get(Base.loaded_modules, Base.PkgId(Base.UUID("3fa0cd96-eef1-5676-8a61-b3b8758bbffb"), "REPL"), nothing)
    REPL === nothing && return
    dict = Dict{Symbol, Expr}(Symbol(k) => v for (ks, v) in autoloads for k in ks)
    already_ran = Set{Expr}()
    autoload(expr) = _for_each_symbol(expr) do sym::Symbol
        target = get(dict, expr.args[1], nothing)
        target === nothing && return
        target in already_ran && return
        push!(already_ran, target)
        @info "BasicAutoloads is running `$target`..."
        try
            Main.eval(target)
        catch err
            @info "Failed to rung `$target`" exception=err
        end
    end
    pushfirst!(REPL.repl_ast_transforms, autoload)
    nothing
end

function _for_each_symbol(f, expr)
    if expr isa Expr
        foreach(_for_each_symbol, expr.args)
    elseif expr isa Symbol
        f(expr)
    end
    expr
end

precompile(register_autoloads, (Vector{Pair{Vector{String}, Expr}},))
precompile(Base.vect, (Pair{Array{String, 1}, Expr}, Vararg{Pair{Array{String, 1}, Expr}},))

end
