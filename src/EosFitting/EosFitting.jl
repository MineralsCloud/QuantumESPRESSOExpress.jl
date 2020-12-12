module EosFitting

using AbInitioSoftwareBase.Inputs: Setter
using Crystallography: cellvolume
using Dates: format, now
using Distributed: LocalManager
using EquationsOfStateOfSolids.Collections: EquationOfStateOfSolids, PressureEOS, getparam
using EquationsOfStateOfSolids.Volume: mustfindvolume
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, PWInput, VerbositySetter, VolumeSetter, PressureSetter
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using QuantumESPRESSO.CLI: PWX
using Setfield: @set!
using Unitful: Pressure, Volume, uparse, ustrip, dimension, @u_str
import Unitful
using UnitfulAtomic

using Express: SelfConsistentField, Optimization
import Express.EosFitting:
    StOptim,
    VcOptim,
    ScfOrOptim,
    standardize,
    customize,
    check_software_settings,
    expand_settings,
    expandeos,
    shortname,
    parseoutput

include("settings.jl")
include("standardize.jl")
include("customize.jl")

shortname(::Type{SelfConsistentField}) = "scf"
shortname(::Type{StOptim}) = "relax"
shortname(::Type{VcOptim}) = "vc-relax"

function parseoutput(::SelfConsistentField)
    function (file)
        str = read(file, String)
        preamble = tryparse(Preamble, str)
        e = try
            parse_electrons_energies(str, :converged)
        catch
        end
        if preamble !== nothing && e !== nothing
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
