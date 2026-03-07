using Documenter
using Gamen

makedocs(
    sitename = "Gamen.jl",
    modules = [Gamen],
    pages = [
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "Book Reference" => "book_reference.md",
        "API Reference" => "api.md",
    ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    remotes = nothing,
    doctest = true,
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/USERNAME/Gamen.jl.git",
    devbranch = "main",
)
