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
        ["pager"]                => :(using TerminalPager),
        ["cowsay"]               => :(cowsay(x) = println("Cow: \"\$x\"")),
    ])
end
```
"""
function register_autoloads(autoloads::Vector{Pair{Vector{String}, Expr}})
    if is_repl_ready()
        _register_ast_transform(autoloads)
    else
        t = Task(Fix(_register_ast_transform_when_ready, (autoloads,)))
        schedule(t)
        isdefined(Base, :errormonitor) && Base.errormonitor(t)
    end
    nothing
end

# This callable struct is to avoid anonymous functions which are harder to precompile.
# We could use Base.Fix if it were not for compatability with Julia 1.10, 1.6, and 1.0.
struct Fix{F, X}
    f::F
    x::X
end
(r::Fix)(args...) = r.f(r.x..., args...)

is_repl_ready() = isdefined(Base, :active_repl_backend) && isdefined(Base.active_repl_backend, :ast_transforms)
function _register_ast_transform_when_ready(autoloads)
    iter = 0
    while !is_repl_ready() && iter < 120
        iter += 1
        sleep(.02*iter)
    end
    if is_repl_ready()
        _register_ast_transform(autoloads)
    else
        @warn "Timed out waiting for `Base.active_repl_backend.ast_transforms` to become available. Autoloads will not work."
        @info "If you have a slow startup file, consider moving `register_autoloads` to the end of it."
    end
end

function _register_ast_transform(autoloads)
    dict = Dict{Symbol, Expr}(Symbol(k) => v for (ks, v) in autoloads for k in ks)
    pushfirst!(Base.active_repl_backend.ast_transforms, Fix(autoload, (dict, Set{Expr}())))
    # Hack the autoloads into autocompletion by hijacking REPL's list of keywords.
    # Workaround for https://github.com/JuliaLang/julia/issues/56101
    keywords = typeof(Base.active_repl_backend).name.module.REPLCompletions.sorted_keywords
    for trigger in keys(dict)
        str = string(trigger)
        insert!(keywords, searchsortedfirst(keywords, str), str)
    end
end

function autoload(dict::Dict{Symbol, Expr}, already_ran::Set{Expr}, @nospecialize(expr))
    if expr isa Expr
        foreach(expr.args) do expr
            autoload(dict, already_ran, expr)
        end
    elseif expr isa QuoteNode
        autoload(dict, already_ran, expr.value)
    elseif expr isa Symbol
        target = get(dict, expr, nothing)
        target === nothing && return expr
        target in already_ran && return expr
        push!(already_ran, target)
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

precompile(Tuple{typeof(Base.vect), Pair{Vector{String}, Expr}, Vararg{Pair{Vector{String}, Expr}}})
precompile(Tuple{typeof(BasicAutoloads.register_autoloads), Vector{Pair{Vector{String}, Expr}}})
precompile(Tuple{Fix{typeof(_register_ast_transform_when_ready), Tuple{Vector{Pair{Vector{String}, Expr}}}}})
precompile(Tuple{Fix{typeof(autoload), Tuple{Dict{Symbol, Expr}, Set{Expr}}}, Expr})

end
