struct CalculationSetter{T<:Union{Scf,Dfpt}} <: Setter
    calc::T
end
function (::CalculationSetter{Scf})(template::PWInput)
    @set! template.control.calculation = "scf"
    return template
end

struct Normalizer{T}
    calc::T
end
function (x::Normalizer{Scf})(template::PWInput)::PWInput
    normalize = VerbositySetter("high") ∘ CalculationSetter(Scf())
    return normalize(template)
end
(x::Normalizer{Dfpt})(template::PhInput)::PhInput = VerbositySetter("high")(template)
(x::Normalizer{RealSpaceForceConstants})(template::Q2rInput)::Q2rInput = template
function (x::Normalizer{PhononDispersion})(template::MatdynInput)::MatdynInput
    @set! template.input.dos = false
    return template
end
function (x::Normalizer{VDos})(template::MatdynInput)::MatdynInput
    @set! template.input.dos = true
    return template
end
