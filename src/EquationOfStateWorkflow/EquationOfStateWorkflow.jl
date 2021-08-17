module EquationOfStateWorkflow

using Crystallography: cellvolume
using QuantumESPRESSO.Commands: PwxConfig, makecmd
using QuantumESPRESSO.Inputs.PWscf: CellParametersCard
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using Setfield: @set!
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

using ..QuantumESPRESSOExpress: QE

using Express.EquationOfStateWorkflow: SelfConsistentField, StOptim, VcOptim, ScfOrOptim
import Express.EquationOfStateWorkflow.DefaultActions: parseoutput

include("Config.jl")
include("DefaultActions.jl")

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
