using BasicAutoloads
using Test
using Aqua

@testset "BasicAutoloads.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(BasicAutoloads, deps_compat=false)
        Aqua.test_deps_compat(BasicAutoloads, check_extras=false)
    end

    @testset "Input traversal" begin
        a, b = Ref(0), Ref(0)
        dict = Dict(:a1 => :($a[] += 1), :a2 => :($a[] += 1), :b => :($b[] += 1))
        already_ran = Set{Expr}()
        expr = quote
            a1(:b, 1, nothing)
            a2
        end
        for _ in 1:2
            @test BasicAutoloads.autoload(dict, already_ran, expr) === expr
            @test (a[], b[]) == (1, 1)
        end
    end

    # Package images cache native code only since Julia 1.9.
    VERSION >= v"1.9" && @testset "No compilation at startup or first input" begin
        # Registration precedes the REPL backend, as in startup.jl, and the
        # registration task waits at least once. Everything the script itself
        # calls inside the START-END window is compiled before START. Autoload
        # vectors with one entry and with several entries call different
        # Base.vect signatures. The one-entry vector comes first because a
        # cached several-entry specialization also matches one entry.
        script = """
        using REPL
        backend = REPL.REPLBackend(Channel(1), Channel(1), false)
        transforms = backend.ast_transforms
        n = length(transforms)
        input = quote
            probe(:x, "s", 1.5, nothing)
            let y = [1, 2]
                @probe y
            end
        end
        deadline = time() + 60
        time() < deadline
        using BasicAutoloads
        println(stderr, "START")
        [["single"] => :(single = 1)]
        register_autoloads([["probe", "@probe"] => :(probe_loaded = 1), ["other"] => :(other = 1)])
        yield()
        Core.eval(Base, :(active_repl_backend = \$backend))
        while length(transforms) == n
            time() < deadline || error("The autoload transform was not registered.")
            yield()
        end
        transforms[1](input)
        println(stderr, "END")
        probe_loaded == 1 || error("The autoload target did not run.")
        """
        # Without the flags of Base.julia_cmd(), such as --check-bounds=yes from Pkg.test,
        # the subprocess uses the same native code caches as an interactive session.
        julia = joinpath(Sys.BINDIR, Base.julia_exename())
        cmd = `$julia --startup-file=no --project=$(Base.active_project()) --trace-compile=stderr -e $script`
        buffer = IOBuffer()
        process = run(pipeline(ignorestatus(cmd); stdout=buffer, stderr=buffer))
        output = String(take!(buffer))
        success(process) || println(output)
        @test success(process)
        lines = split(output, '\n')
        markers = filter(in(("START", "END")), lines)
        @test markers == ["START", "END"]
        if markers == ["START", "END"]
            compiled = lines[findfirst(==("START"), lines) + 1:findfirst(==("END"), lines) - 1]
            @test compiled == String[]
        end
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
