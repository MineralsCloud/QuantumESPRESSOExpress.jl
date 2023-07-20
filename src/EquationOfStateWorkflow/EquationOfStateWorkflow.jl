module EquationOfStateWorkflow

using Crystallography: cellvolume
using QuantumESPRESSO.PWscf:
    CellParametersCard,
    Preamble,
    parse_electrons_energies,
    parsefinal,
    isjobdone,
    tryparsefinal
using Unitful: @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow: ExtractData

include("Config.jl")
include("actions.jl")
# include("DB.jl")

struct DataExtractionFailed <: Exception
    msg::String
end

function (::ExtractData{SelfConsistentField})(file)
    str = read(file, String)
    preamble = tryparse(Preamble, str)
    e = try
        parse_electrons_energies(str, :converged)
    catch
    end
    if preamble !== nothing && !isempty(e)
        return preamble.omega * u"bohr^3" => e.ε[end] * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end
function (::ExtractData{VariableCellOptimization})(file)
    str = read(file, String)
    if !isjobdone(str)
        @warn "Job is not finished!"
    end
    x = tryparsefinal(CellParametersCard, str)
    if x !== nothing
        return cellvolume(parsefinal(CellParametersCard, str)) * u"bohr^3" =>
            parse_electrons_energies(str, :converged).ε[end] * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end

end
