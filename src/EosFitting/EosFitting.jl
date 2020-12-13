module EosFitting

using AbInitioSoftwareBase.Inputs: Setter
using Crystallography: cellvolume
using Dates: format, now
using Distributed: LocalManager
using EquationsOfStateOfSolids.Collections:
    EquationOfStateOfSolids, PressureEOS, Parameters, getparam
using EquationsOfStateOfSolids.Volume: mustfindvolume
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, PWInput, VerbositySetter, VolumeSetter, PressureSetter
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using QuantumESPRESSO.CLI: PWX
using Setfield: @set!
using Unitful: Pressure, Volume, @u_str
import Unitful
using UnitfulAtomic

using ..QuantumESPRESSOExpress: QE

using Express: SelfConsistentField, Optimization
using Express.EosFitting:
    UNIT_CONTEXT,
    StOptim,
    VcOptim,
    ScfOrOptim,
    materialize_eos,
    materialize_press,
    materialize_vol,
    materialize_dirs
import Express.EosFitting: checkconfig, materialize, shortname
import Express.EosFitting.DefaultActions: adjust, parseoutput

include("config.jl")
include("normalizer.jl")
include("customizer.jl")

adjust(template::PWInput, x::ScfOrOptim, args...) =
    (Customizer(args...) ∘ Normalizer(x))(template)

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
