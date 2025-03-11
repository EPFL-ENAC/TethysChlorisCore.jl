using TethysChlorisCore
using TethysChlorisCore.ModelComponents
using Documenter

DocMeta.setdocmeta!(
    TethysChlorisCore, :DocTestSetup, :(using TethysChlorisCore); recursive=true
)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules=[TethysChlorisCore, TethysChlorisCore.ModelComponents],
    authors="Hugo Solleder <hugo.solleder@epfl.ch>",
    repo="https://github.com/EPFL-ENAC/TethysChlorisCore.jl/blob/{commit}{path}#{line}",
    sitename="TethysChlorisCore.jl",
    format=Documenter.HTML(; canonical="https://EPFL-ENAC.github.io/TethysChlorisCore.jl"),
    pages=["index.md"; numbered_pages],
)

deploydocs(; repo="github.com/EPFL-ENAC/TethysChlorisCore.jl")
