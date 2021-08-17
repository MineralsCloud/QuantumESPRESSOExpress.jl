module EquationOfStateWorkflow

using Crystallography: cellvolume
using QuantumESPRESSOCli: PwxConfig, makecmd
using QuantumESPRESSO.Inputs.PWscf: CellParametersCard
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using Setfield: @set!
using Unitful: Pressure, Volume, @u_str
import Unitful
using UnitfulAtomic

using ..QuantumESPRESSOExpress: QE

using Express: loadconfig
using Express.EosFitting: SelfConsistentField, StOptim, VcOptim, ScfOrOptim, iofiles
import Express.EosFitting.DefaultActions: parseoutput

include("Config.jl")

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

include("MakeInput.jl")
include("MakeCmd.jl")

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
