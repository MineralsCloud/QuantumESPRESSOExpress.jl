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

function standardize(x::ScfOrOptim)
    function _standardize(template::PWInput)::PWInput
        set = VerbositySetter("high") ∘ CalculationSetter(x)
        return set(template)
    end
end
