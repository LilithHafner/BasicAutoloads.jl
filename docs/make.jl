using BasicAutoloads
using Documenter

DocMeta.setdocmeta!(BasicAutoloads, :DocTestSetup, :(using BasicAutoloads); recursive=true)

makedocs(;
    modules=[BasicAutoloads],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    sitename="BasicAutoloads.jl",
    format=Documenter.HTML(;
        canonical="https://LilithHafner.github.io/BasicAutoloads.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/BasicAutoloads.jl",
    devbranch="main",
)
