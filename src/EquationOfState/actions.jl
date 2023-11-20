using AbInitioSoftwareBase: Setter
using Accessors: @reset
using AtomsIO: Atom, periodic_system, save_system
using CrystallographyBase: Lattice, Cell, basisvectors, cellvolume, eachatom
using Dates: format, now
using EquationsOfStateOfSolids: PressureEquation, Parameters, getparam, vsolve
using ExpressBase: SelfConsistentField, FixedCellOptimization, VariableCellOptimization
using QuantumESPRESSO.PWscf:
    CellParametersCard,
    AtomicPositionsCard,
    PWInput,
    VerbositySetter,
    VolumeSetter,
    PressureSetter,
    CardSetter,
    Preamble,
    isjobdone,
    isoptimized,
    eachcellparameterscard,
    eachatomicpositionscard,
    eachconvergedenergy
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.EquationOfState:
    CreateInput, FitEquationOfState, ExtractData, ExtractCell, SaveCell

(::CreateInput{T})(template::PWInput, volume_or_cell) where {T} =
    (customizer(volume_or_cell) ∘ normalizer(T()))(template)

struct CalculationSetter{T} <: Setter
    calculation::T
end
function (x::CalculationSetter)(template::PWInput)
    @reset template.control.calculation = if x.calculation isa SelfConsistentField  # Functions can be extended, not safe
        "scf"
    elseif x.calculation isa FixedCellOptimization
        "relax"
    elseif x.calculation isa VariableCellOptimization
        "vc-relax"
    else
        throw(ArgumentError("this should never happen!"))
    end
    return template
end

struct PseudoDirSetter <: Setter end
function (x::PseudoDirSetter)(template::PWInput)
    @reset template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

normalizer(calculation) =
    VerbositySetter("high") ∘ CalculationSetter(calculation) ∘ PseudoDirSetter()

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    # Set `outdir` to `outdir` + a subdirectory.
    @reset template.control.outdir = abspath(
        joinpath(
            template.control.outdir,
            join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
        ),
    )
    if !isdir(template.control.outdir)
        mkpath(template.control.outdir)
    end
    return template
end

customizer(volume::Volume) = OutdirSetter("Y-m-d_H:M:S") ∘ VolumeSetter(volume)
customizer(cell::Cell) =
    OutdirSetter("Y-m-d_H:M:S") ∘ CardSetter(CellParametersCard(cell, :bohr)) ∘
    CardSetter(AtomicPositionsCard(cell))

struct DataExtractionFailed <: Exception
    msg::String
end

function (::ExtractData{SelfConsistentField})(file)
    str = read(file, String)
    preamble = tryparse(Preamble, str)
    energies = collect(eachconvergedenergy(str))
    if !isnothing(preamble) && !isempty(energies)
        return preamble.omega * u"bohr^3" => last(energies).total * u"Ry"  # volume, energy
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
    cards, energies = collect(eachcellparameterscard(str)),
    collect(eachconvergedenergy(str))
    if !isempty(cards) && !isempty(energies)
        lastcell, lastenergy = last(cards), last(energies).total
        return cellvolume(lastcell) * u"bohr^3" => lastenergy * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end

function (::ExtractCell)(file)
    str = read(file, String)
    cell_parameters = last(collect(eachcellparameterscard(str)))
    atomic_positions = last(collect(eachatomicpositionscard(str)))
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
