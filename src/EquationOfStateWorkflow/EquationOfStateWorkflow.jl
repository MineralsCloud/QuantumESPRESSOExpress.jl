module EquationOfStateWorkflow

using AtomsIO: Atom, periodic_system, save_system
using CrystallographyBase: Lattice, Cell, basisvectors, cellvolume, eachatom
using ExpressBase: Calculation
using QuantumESPRESSO.PWscf:
    CellParametersCard,
    AtomicPositionsCard,
    Preamble,
    parse_electrons_energies,
    parsefinal,
    isjobdone,
    tryparsefinal
using Unitful: @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow: ExtractData, ExtractCell, SaveCell

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

function (::ExtractCell)(file)
    str = read(file, String)
    cell_parameters = parsefinal(CellParametersCard, str)
    atomic_positions = parsefinal(AtomicPositionsCard, str)
    return Cell(cell_parameters, atomic_positions)
end

function (action::SaveCell)(path, cell)
    lattice = Lattice(cell)
    lattice *= 1u"bohr"
    box = collect(basisvectors(lattice))
    atomicpositions = map(eachatom(cell)) do (atom, position)
        Atom(Symbol(atom), lattice(position))
    end
    system = periodic_system(atomicpositions, box; fractional=true)
    return save_system(path, system)
end

end
