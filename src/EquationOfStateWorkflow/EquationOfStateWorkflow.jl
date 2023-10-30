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
    energies = eachconvergedenergy(str)
    if !isnothing(preamble) && !isempty(energies)
        return preamble.omega * u"bohr^3" => last(energies) * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end
function (::ExtractData{VariableCellOptimization})(file)
    str = read(file, String)
    if !isjobdone(str)
        @warn "Job is not finished!"
    end
    if !isoptimized(str)
        @warn "Cell is not completely optimized!"
    end
    cards, energies = eachcellparameterscard(str), eachconvergedenergy(str)
    if !isempty(cards) && !isempty(energies)
        lastcell, lastenergy = last(cards), last(energies)
        return cellvolume(lastcell) * u"bohr^3" => lastenergy * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end

function (::ExtractCell)(file)
    str = read(file, String)
    cell_parameters = last(eachcellparameterscard(str))
    atomic_positions = last(eachatomicpositionscard(str))
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
