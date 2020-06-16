using QuantumESPRESSOExpress
using Documenter

makedocs(;
    modules=[QuantumESPRESSOExpress],
    authors="Qi Zhang <singularitti@outlook.com>",
    repo="https://github.com/MineralsCloud/QuantumESPRESSOExpress.jl/blob/{commit}{path}#L{line}",
    sitename="QuantumESPRESSOExpress.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://MineralsCloud.github.io/QuantumESPRESSOExpress.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/MineralsCloud/QuantumESPRESSOExpress.jl",
)
