function time_to_repl(args)
    code = """
        spawn julia -qi $args
        expect {
            -timeout 5
            "julia>"
        }
    """
    @elapsed run(`expect -c "$code"`, devnull, devnull)
end

function bench()
    # Extract example startup.jl file from the ```julia block in the README.md
    readme_file = joinpath(dirname(@__DIR__), "README.md")
    readme_content = read(readme_file, String)
    julia_block = match(r"```julia\n((\n|.)*?)\n```", readme_content)


    mktempdir() do depot
        # Save the extracted content to a startup.jl file in the temporary depot directory
        startup_file = joinpath(depot, "config", "startup.jl")
        mkdir(dirname(startup_file))
        open(startup_file, "w") do f
            write(f, julia_block.captures[1])
        end

        # Link to the existing general registry so that we don't have to download it
        general_link = joinpath(depot, "registries", "General")
        mkpath(dirname(general_link))
        general_target = joinpath(DEPOT_PATH[1], "registries", "General")
        symlink(general_target, general_link)

        # Set the JULIA_DEPOT_PATH to the temporary directory
        old_depot = get(ENV, "JULIA_DEPOT_PATH", bench)
        ENV["JULIA_DEPOT_PATH"] = depot
        try
            # Add autoloads to the default environment and time the installation (excluding warmup)
            run(`julia --startup=no -e 'using Pkg; Pkg.UPDATED_REGISTRY_THIS_SESSION[] = true; Pkg.develop(path="$(@__DIR__)", io=devnull)'`)
            [time_to_repl("") for _ in 1:6]
        finally
            if old_depot === bench
                # If the old depot was not set, remove the environment variable
                delete!(ENV, "JULIA_DEPOT_PATH")
            else
                # Restore the old depot path
                ENV["JULIA_DEPOT_PATH"] = old_depot
            end
        end
    end
end
