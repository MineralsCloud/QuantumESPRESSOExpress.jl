struct CalculationSetter{T<:Union{Scf,Dfpt}} <: Setter
    calc::T
end
function (::CalculationSetter{Scf})(template::PWInput)
    @set! template.control.calculation = "scf"
    return template
end

struct Normalizer{T,S}
    calc::T
    args::S
end
function (x::Normalizer{Scf})(template::PWInput)::PWInput
    normalize = VerbositySetter("high") ∘ CalculationSetter(Scf())
    return normalize(template)
end
function (x::Normalizer{Dfpt,PWInput})(template::PhInput)::PhInput
    normalize = Base.Fix1(relayinfo, x.args) ∘ VerbositySetter("high")
    return normalize(template)
end
(x::Normalizer{RealSpaceForceConstants,PhInput})(template::Q2rInput)::Q2rInput =
    relayinfo(x.args, template)
function (
    x::Normalizer{
        PhononDispersion,
        <:Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}},
    }
)(
    template::MatdynInput,
)::MatdynInput
    @set! template.input.dos = false
    normalize = Base.Fix1(relayinfo, x.args[2]) ∘ Base.Fix1(relayinfo, x.args[1])
    return normalize(template)
end
function (x::Normalizer{VDos,<:Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}}})(
    template::MatdynInput,
)::MatdynInput
    @set! template.input.dos = true
    normalize = Base.Fix1(relayinfo, x.args[2]) ∘ Base.Fix1(relayinfo, x.args[1])
    return normalize(template)
end
