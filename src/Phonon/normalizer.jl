struct CalculationSetter{T<:Union{Scf,Dfpt}} <: Setter
    calc::T
end
function (::CalculationSetter{Scf})(template::PWInput)
    @set! template.control.calculation = "scf"
    return template
end

struct Normalizer{T,S}
    calc::T
    previnput::S
end
function (x::Normalizer{Scf})(template::PWInput)::PWInput
    normalize = VerbositySetter("high") ∘ CalculationSetter(Scf())
    return normalize(template)
end
function (x::Normalizer{Dfpt,PWInput})(template::PhInput)::PhInput
    normalize = Base.Fix1(relayinfo, x.previnput) ∘ VerbositySetter("high")
    return normalize(template)
end
(x::Normalizer{RealSpaceForceConstants,PhInput})(template::Q2rInput)::Q2rInput =
    relayinfo(x.previnput, template)
function (x::Normalizer{PhononDispersion,Q2rInput})(template::MatdynInput)::MatdynInput
    @set! template.input.dos = false
    return relayinfo(x.previnput, template)
end
function (x::Normalizer{VDos,Q2rInput,PhInput})(template::MatdynInput)::MatdynInput
    @set! template.input.dos = true
    normalize = Base.Fix1(relayinfo, x.previnput) ∘ Base.Fix1(relayinfo, x.previnput)
    return normalize(template)
end
