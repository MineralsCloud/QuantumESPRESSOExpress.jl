module DefaultActions

using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Commands: MpiexecConfig
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using EquationsOfStateOfSolids: EquationOfStateOfSolids, PressureEquation, Parameters
using Express.Config: loadconfig
using Express.EquationOfStateWorkflow.Config: Volumes
using Express.EquationOfStateWorkflow: SelfConsistentField, StOptim, VcOptim, ScfOrOptim
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow.DefaultActions: MakeInput, FitEos, RunCmd
import Express.Shell: distprocs

(::MakeInput{T})(template::PWInput, args...) where {T<:ScfOrOptim} =
    (customizer(args...) ∘ normalizer(T()))(template)
function (x::MakeInput{T})(cfgfile) where {T}
    config = loadconfig(cfgfile)
    infiles = first.(config.files)
    eos = PressureEquation(
        T <: SelfConsistentField ? config.trial_eos :
        FitEos{SelfConsistentField}()(cfgfile),
    )
    if config.fixed isa Volumes
        return broadcast(
            x,
            infiles,
            config.template,
            config.fixed,
            fill("Y-m-d_H:M:S", length(infiles)),
        )
    else  # Pressure
        return broadcast(
            x,
            infiles,
            config.template,
            fill(eos, length(infiles)),
            config.fixed,
            fill("Y-m-d_H:M:S", length(infiles)),
        )
    end
end

struct CalculationSetter <: Setter
    calc::ScfOrOptim
end
function (x::CalculationSetter)(template::PWInput)
    @set! template.control.calculation = if x.calc isa SelfConsistentField  # Functions can be extended, not safe
        "scf"
    elseif x.calc isa StOptim
        "relax"
    else
        "vc-relax"
    end
    return template
end

normalizer(calc::ScfOrOptim) = VerbositySetter("high") ∘ CalculationSetter(calc)

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

customizer(volume::Volume, timefmt = "Y-m-d_H:M:S") =
    OutdirSetter(timefmt) ∘ VolumeSetter(volume)
function customizer(eos::PressureEquation, pressure::Pressure, timefmt = "Y-m-d_H:M:S")
    volume = (eos^(-1))(pressure)
    return OutdirSetter(timefmt) ∘ PressureSetter(pressure) ∘ VolumeSetter(volume)
end
customizer(params::Parameters, pressure::Pressure, timefmt = "Y-m-d_H:M:S") =
    customizer(PressureEquation(params), pressure, timefmt)

(x::RunCmd)(input; output, error = output, kwargs...) = pw(input, output, error; kwargs...)
function (x::RunCmd)(cfgfile; kwargs...)
    config = loadconfig(cfgfile)
    @set! mpi.np = distprocs(mpi.np, length(config.files))
    map(config.files) do input, output
        x(input; output = output, kwargs...)
    end
end

end
