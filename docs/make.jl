using UniAdminTools
using Documenter

DocMeta.setdocmeta!(UniAdminTools, :DocTestSetup, :(using UniAdminTools); recursive = true)

makedocs(;
    modules = [UniAdminTools],
    authors = "MilesCranmer <miles.cranmer@gmail.com> and contributors",
    repo = "https://github.com/MilesCranmer/UniAdminTools.jl/blob/{commit}{path}#{line}",
    sitename = "UniAdminTools.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://MilesCranmer.github.io/UniAdminTools.jl",
        repolink = "https://github.com/MilesCranmer/UniAdminTools.jl",
        edit_link = "master",
        assets = String[],
    ),
    pages = ["Home" => "index.md", "`mergescore`" => "mergescore.md"],
    warnonly = true,
)

deploydocs(; repo = "github.com/MilesCranmer/UniAdminTools.jl", devbranch = "master")
