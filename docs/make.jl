using QuantumESPRESSOExpress
using Documenter

DocMeta.setdocmeta!(QuantumESPRESSOExpress, :DocTestSetup, :(using QuantumESPRESSOExpress); recursive=true)

makedocs(;
    modules=[QuantumESPRESSOExpress],
    authors="singularitti <singularitti@outlook.com> and contributors",
    repo="https://github.com/MineralsCloud/QuantumESPRESSOExpress.jl/blob/{commit}{path}#{line}",
    sitename="QuantumESPRESSOExpress.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://MineralsCloud.github.io/QuantumESPRESSOExpress.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "Installation guide" => "installation.md",
        ],
        # "API Reference" => "public.md",
        "Developer Docs" => [
            "Contributing" => "developers/contributing.md",
            "Style Guide" => "developers/style.md",
        ],
        "Troubleshooting" => "troubleshooting.md",
        "FAQ" => "faq.md",
    ],
)

deploydocs(;
    repo="github.com/MineralsCloud/QuantumESPRESSOExpress.jl",
    devbranch="main",
)
