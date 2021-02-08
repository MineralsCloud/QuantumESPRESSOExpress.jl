(::MakeInput{T})(template::PWInput, args...) where {T<:ScfOrOptim} =
    (Customizer(args...) ∘ Normalizer(T()))(template)
function (x::MakeInput{T})(cfgfile) where {T}
    config = loadconfig(cfgfile)
    infiles = first.(iofiles(T(), cfgfile))
    eos = PressureEquation(
        T <: SelfConsistentField ? config.trial_eos :
        FitEos{SelfConsistentField}()(cfgfile),
    )
    if eltype(config.fixed) <: Volume
        return broadcast(x, infiles, config.templates, config.trial_eos, config.fixed)
    else  # Pressure
        return broadcast(
            x,
            infiles,
            config.templates,
            config.fixed,
            fill(nothing, length(infiles)),
            "Y-m-d_H:M:S",
            config.num_inv,
        )
    end
end

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
    volume::Volume
    pressure::Union{Pressure,Nothing}
    timefmt::String
end
Customizer(volume, pressure = nothing, timefmt = "Y-m-d_H:M:S") =
    Customizer(volume, pressure, timefmt)
function Customizer(
    eos::EquationOfStateOfSolids,
    pressure::Pressure,
    timefmt,
    num_inv = NumericalInversionOptions(),
)
    volume = inverse(eos)(pressure, num_inv)
    return Customizer(volume, pressure, timefmt)
end
Customizer(params::Parameters, pressure::Pressure, args...) =
    Customizer(PressureEquation(params), pressure, args...)
function (x::Customizer)(template::PWInput)::PWInput
    customize = if x.pressure === nothing
        OutdirSetter(x.timefmt) ∘ VolumeSetter(x.volume)
    else
        OutdirSetter(x.timefmt) ∘ PressureSetter(x.pressure) ∘ VolumeSetter(x.volume)
    end
    return customize(template)
end
