module BasicAutoloads

export register_autoloads

"""
    register_autoloads(autoloads::Vector{Pair{Vector{String}, Expr}})
    register_autoloads([
        [trigger1, trigger2, ...]   => expr1,
        [trigger10, trigger11, ...] => expr2,
        ...
    ])

Register expressions to be executed when a trigger is found in the REPL's input.

Each `trigger` must be a `String`. If the `trigger` is found as a symbol (e.g. variable,
function, or macro name) in an input expression to the REPL, the corresponding `expr` is
evaluated. Each `expr` must be an `Expr` and is evaluated with `Main.eval(expr)`. Each
unique `expr`, up to equality, is evaluated at most once.

This function is meant to be called from `~/.julia/config/startup.jl` (or wherever your
startup.jl file happens to be stored), but will also work if called from the REPL.

# Example

```julia
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
    _register_ast_transform(_Autoload(autoloads))
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
    elseif expr isa QuoteNode
        al(expr.value)
    elseif expr isa Symbol
        target = get(al.dict, expr, nothing)
        target === nothing && return expr
        target in al.already_ran && return expr
        push!(al.already_ran, target)
        try
            try_autoinstall(target)
            Main.eval(target)
        catch err
            @info "Failed to run `$target`" exception=err
        end
    end
    expr
end
function try_autoinstall(expr::Expr)
    isdefined(Base, :active_repl_backend) || return
    REPL = typeof(Base.active_repl_backend).name.module
    isdefined(REPL, :install_packages_hooks) || return
    expr.head in (:using, :import) || return
    for arg in expr.args
        arg isa Expr && arg.head == :. && length(arg.args) == 1 || continue
        mod = only(arg.args)
        mod isa Symbol && Base.identify_package(String(mod)) === nothing || continue
        isempty(REPL.install_packages_hooks) && isdefined(REPL, :load_pkg) && REPL.load_pkg()
        for f in REPL.install_packages_hooks
            Base.invokelatest(f, [mod]) && break
        end
    end
end

function _register_ast_transform(ast_transform)
    if isdefined(Base, :active_repl_backend)
        if isdefined(Base.active_repl_backend, :ast_transforms)
            pushfirst!(Base.active_repl_backend.ast_transforms, ast_transform)
        else
            @warn "Failed to find Base.active_repl_backend.ast_transforms"
        end
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
    while !isdefined(Base, :active_repl_backend) && iter < 30
        iter += 1
        sleep(.02*iter)
    end
    if isdefined(Base, :active_repl_backend)
        if isdefined(Base.active_repl_backend, :ast_transforms)
            pushfirst!(Base.active_repl_backend.ast_transforms, wrat.ast_transform)
        else
            @warn "Failed to find Base.active_repl_backend.ast_transforms. Autoloads will not work."
        end
    else
        @warn "Timed out waiting to Base.active_repl_backend to be defined. Autoloads will not work."
        @info "If you have a slow startup file, consider moving `register_autoloads` to the end of it."
    end
end

precompile(Tuple{typeof(Base.vect), Pair{Array{String, 1}, Expr}, Vararg{Pair{Array{String, 1}, Expr}}})
precompile(Tuple{typeof(BasicAutoloads.register_autoloads), Array{Pair{Array{String, 1}, Expr}, 1}})
precompile(Tuple{BasicAutoloads._WaitRegisterASTTransform{BasicAutoloads._Autoload}})
precompile(Tuple{BasicAutoloads._Autoload, Any})

end

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
