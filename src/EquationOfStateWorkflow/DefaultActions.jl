module DefaultActions

using AbInitioSoftwareBase.Commands: MpiexecConfig
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using EquationsOfStateOfSolids: EquationOfStateOfSolids, PressureEquation, Parameters
using QuantumESPRESSO.Commands: PwxConfig, makecmd
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using SimpleWorkflows: ExternalAtomicJob, parallel
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

using Express.Config: loadconfig
using Express.EquationOfStateWorkflow: SelfConsistentField, StOptim, VcOptim, ScfOrOptim
import Express.EquationOfStateWorkflow.DefaultActions: MakeInput, FitEos, MakeCmd
import Express.Shell: distprocs

(::MakeInput{T})(template::PWInput, args...) where {T<:ScfOrOptim} =
    (Customizer(args...) ∘ Normalizer(T()))(template)
function (x::MakeInput{T})(cfgfile) where {T}
    config = loadconfig(cfgfile)
    infiles = first.(config.files)
    eos = PressureEquation(
        T <: SelfConsistentField ? config.trial_eos :
        FitEos{SelfConsistentField}()(cfgfile),
    )
    if eltype(config.fixed) <: Volume
        return broadcast(
            x,
            infiles,
            config.template,
            fill(eos, length(infiles)),
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

customizer(volume::Volume, pressure::Pressure, timefmt = "Y-m-d_H:M:S") =
    OutdirSetter(timefmt) ∘ PressureSetter(pressure) ∘ VolumeSetter(volume)
customizer(volume::Volume, timefmt = "Y-m-d_H:M:S") =
    OutdirSetter(timefmt) ∘ VolumeSetter(volume)
function customizer(eos::PressureEquation, pressure::Pressure, timefmt = "Y-m-d_H:M:S")
    volume = (eos^(-1))(pressure)
    return customizer(volume, pressure, timefmt)
end
customizer(params::Parameters, pressure::Pressure, timefmt = "Y-m-d_H:M:S") =
    customizer(PressureEquation(params), pressure, timefmt)

function (x::MakeCmd)(
    inputs::AbstractArray;
    outputs,
    errors = outputs,
    mpi,
    options = PwxConfig(),
)
    if !isempty(outputs)
        if size(inputs) != size(outputs)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    if !isempty(errors)
        if size(inputs) != size(errors)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    @set! mpi.np = distprocs(mpi.np, length(inputs))
    distkeys = []
    for (key, value) in mpi.options
        if value isa AbstractArray
            push!(distkeys, key)
        end
    end
    return map(enumerate(inputs)) do (i, input)
        tempmpi = mpi
        for key in distkeys
            @set! tempmpi.options[key] = mpi.options[key][i]
        end
        x(input; output = outputs[i], error = errors[i], mpi = tempmpi, options = options)
    end
end

end
