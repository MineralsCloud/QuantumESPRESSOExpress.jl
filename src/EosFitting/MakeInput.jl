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

struct Customizer
    pressure::Pressure
    volume::Volume
    timefmt::String
end
Customizer(a, b, timefmt = "Y-m-d_H:M:S") = Customizer(a, b, timefmt)
function Customizer(pressure, eos::EquationOfStateOfSolids, timefmt)
    volume = inverse(eos)(pressure, config.num_inv)
    return Customizer(pressure, volume, timefmt)
end
Customizer(pressure, params::Parameters, timefmt) =
    Customizer(pressure, PressureEquation(params), timefmt)
function (x::Customizer)(template::PWInput)::PWInput
    customize =
        OutdirSetter(x.timefmt) ∘ VolumeSetter(x.volume) ∘ PressureSetter(x.pressure)
    return customize(template)
end
