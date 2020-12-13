struct CalculationSetter{T<:Union{SelfConsistentField,Optimization}} <: Setter
    calc::T
end
function (::CalculationSetter{T})(template::PWInput) where {T}
    @set! template.control.calculation = if T == SelfConsistentField  # Functions can be extended, not safe
        "scf"
    elseif T == StOptim
        "relax"
    else
        "vc-relax"
    end
    return template
end

struct Normalizer{T}
    calc::T
end
function (x::Normalizer)(template::PWInput)::PWInput
    normalize = VerbositySetter("high") ∘ CalculationSetter(x.calc)
    return normalize(template)
end
