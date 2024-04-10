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
    isinteractive() && _register_ast_transform(_Autoload(autoloads))
    nothing
end

struct _Autoload # These callable structs are to enable precompilation.
    dict::Dict{Symbol, Expr}
    already_ran::Set{Expr}
    _Autoload(autoloads) = new(Dict{Symbol, Expr}(Symbol(k) => v for (ks, v) in autoloads for k in ks), Set{Expr}())
end
function (al::_Autoload)(@nospecialize(expr))
    if expr isa Expr
        foreach(al, expr.args)
    elseif expr isa Symbol
        target = get(al.dict, expr, nothing)
        target === nothing && return expr
        target in al.already_ran && return expr
        push!(al.already_ran, target)
        @info "running `$target`..."
        try
            Main.eval(target)
        catch err
            @info "Failed to rung `$target`" exception=err
        end
    end
    expr
end

function _register_ast_transform(ast_transform)
    if isdefined(Base, :active_repl_backend)
        pushfirst!(Base.active_repl_backend.ast_transforms, ast_transform)
    else
        t = Task(_WaitRegisterASTTransform(ast_transform))
        schedule(t)
        isdefined(Base, :errormonitor) && Base.errormonitor(t)
    end
end

struct _WaitRegisterASTTransform{T}
    ast_transform::T
end
function (wrat::_WaitRegisterASTTransform)()
    iter = 0
    while !isdefined(Base, :active_repl_backend) && iter < 20
        sleep(.05)
        iter += 1
    end
    if isdefined(Base, :active_repl_backend)
        pushfirst!(Base.active_repl_backend.ast_transforms, wrat.ast_transform)
    else
        @warn "Failed to find Base.active_repl_backend"
    end
end

precompile(Tuple{typeof(Base.vect), Pair{Array{String, 1}, Expr}, Vararg{Pair{Array{String, 1}, Expr}}})
precompile(Tuple{typeof(BasicAutoloads.register_autoloads), Array{Pair{Array{String, 1}, Expr}, 1}})
precompile(Tuple{BasicAutoloads._WaitRegisterASTTransform{BasicAutoloads._Autoload}})
precompile(Tuple{BasicAutoloads._Autoload, Any})

end
