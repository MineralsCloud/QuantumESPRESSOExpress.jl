module EosFitting

using AbInitioSoftwareBase.Cli: MpiexecOptions
using Crystallography: cellvolume
using QuantumESPRESSOCli: PwxConfig, makecmd
using QuantumESPRESSO.Inputs.PWscf: CellParametersCard
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using Setfield: @set!
using SimpleWorkflow: ExternalAtomicJob, parallel
using Unitful: Pressure, Volume, @u_str
import Unitful
using UnitfulAtomic

using ..QuantumESPRESSOExpress: QE

using Express: loadconfig
using Express.EosFitting: SelfConsistentField, StOptim, VcOptim, ScfOrOptim, iofiles
import Express.Shell: MakeCmd, distprocs
import Express.EosFitting: shortname, buildjob
import Express.EosFitting.DefaultActions: parseoutput

include("Config.jl")

module DefaultActions

using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using Distributed: LocalManager
using EquationsOfStateOfSolids: EquationOfStateOfSolids, PressureEquation, Parameters
using EquationsOfStateOfSolids.Inverse: inverse
using QuantumESPRESSOCli: PwxConfig, makecmd
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using Unitful: Pressure, Volume, @u_str
import Unitful
using UnitfulAtomic

using Express.EosFitting: SelfConsistentField, Optimization, StOptim, VcOptim, ScfOrOptim
import Express.EosFitting.DefaultActions: MakeInput

include("MakeInput.jl")

end

shortname(::Type{SelfConsistentField}) = "scf"
shortname(::Type{StOptim}) = "relax"
shortname(::Type{VcOptim}) = "vc-relax"

(::MakeCmd)(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecOptions(),
    options = PwxConfig(),
) = makecmd(input; output = output, error = error, mpi = mpi, options = options)
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
    map(inputs, outputs, errors) do input, output, error
        x(input; output = output, error = error, mpi = mpi, options = options)
    end
end

function buildjob(x::MakeCmd{T}, cfgfile) where {T}
    config = loadconfig(cfgfile)
    io = iofiles(T(), cfgfile)
    infiles, outfiles = first.(io), last.(io)
    @show config
    jobs = map(
        ExternalAtomicJob,
        x(infiles; outputs = outfiles, mpi = config.cli.mpi, options = config.cli.pw),
    )
    return parallel(jobs...)
end

function parseoutput(::SelfConsistentField)
    function (file)
        str = read(file, String)
        preamble = tryparse(Preamble, str)
        e = try
            parse_electrons_energies(str, :converged)
        catch
        end
        if preamble !== nothing && !isempty(e)
            return preamble.omega * u"bohr^3" => e.ε[end] * u"Ry"  # volume, energy
        else
            return
        end
    end
end
function parseoutput(::VcOptim)
    function (file)
        str = read(file, String)
        if !isjobdone(str)
            @warn "Job is not finished!"
        end
        x = tryparsefinal(CellParametersCard, str)
        if x !== nothing
            return cellvolume(parsefinal(CellParametersCard, str)) * u"bohr^3" =>
                parse_electrons_energies(str, :converged).ε[end] * u"Ry"  # volume, energy
        else
            return
        end
    end
end

end
