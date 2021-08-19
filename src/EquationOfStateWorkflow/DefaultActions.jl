module DefaultActions

using AbInitioSoftwareBase.Cli: MpiexecOptions
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using EquationsOfStateOfSolids: EquationOfStateOfSolids, PressureEquation, Parameters
using EquationsOfStateOfSolids.Inverse: NumericalInversionOptions, inverse
using QuantumESPRESSOCli: PwxConfig, makecmd
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using SimpleWorkflow: ExternalAtomicJob, parallel
using Unitful: Pressure, Volume, @u_str
import Unitful
using UnitfulAtomic

using Express.EosFitting:
    SelfConsistentField, Optimization, StOptim, VcOptim, ScfOrOptim, iofiles, loadconfig
import Express.EosFitting: buildjob
import Express.EosFitting.DefaultActions: MakeInput, FitEos, MakeCmd
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
    inv_opt = NumericalInversionOptions(),
)
    volume = inverse(eos)(pressure, inv_opt)
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

function (::MakeCmd)(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecOptions(),
    options = PwxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
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

function buildjob(x::MakeCmd{T}, cfgfile) where {T}
    config = loadconfig(cfgfile)
    io = iofiles(T(), cfgfile)
    infiles, outfiles = first.(io), last.(io)
    jobs = map(
        ExternalAtomicJob,
        x(infiles; outputs = outfiles, mpi = config.cli.mpi, options = config.cli.pw),
    )
    return parallel(jobs...)
end

end
