(::MakeInput{T})(template::PWInput, args...) where {T<:ScfOrOptim} =
    (Customizer(args...) ∘ Normalizer(T()))(template)

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

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    @set! template.control.outdir = abspath(
        joinpath(
            template.control.outdir,
            join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
        ),
    )
    mkpath(template.control.outdir)
    return template
end

struct Customizer{A,B}
    a::A
    b::B
    timefmt::String
end
Customizer(a, b) = Customizer(a, b, "Y-m-d_H:M:S")
function (x::Customizer{<:Pressure,<:Volume})(template::PWInput)::PWInput
    customize = OutdirSetter(x.timefmt) ∘ VolumeSetter(x.b) ∘ PressureSetter(x.a)
    return customize(template)
end
function (x::Customizer{<:Pressure,<:EquationOfStateOfSolids})(template::PWInput)
    volume = inverse(x.b)(x.a, config.num_inv)
    x = @set! x.b = volume
    return x(template)
end
function (x::Customizer{<:Pressure,<:Parameters})(template::PWInput)
    x = @set! x.b = PressureEquation(x.b)
    return x(template)
end
(x::Customizer)(template::PWInput) = Customizer(x.b, x.a, x.timefmt)(template)  # If no method found, switch arguments & try again
