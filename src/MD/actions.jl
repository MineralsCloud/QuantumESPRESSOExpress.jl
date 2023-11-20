using AbInitioSoftwareBase: Setter
using CrystallographyBase: Cell
using Dates: format, now
using EquationsOfStateOfSolids: PressureEquation, Parameters, getparam, vsolve
using ExpressBase: IonDynamics, VariableCellMolecularDynamics
using QuantumESPRESSO.PWscf:
    PWInput, VerbositySetter, eachatomicpositionscard, eachcellparameterscard
using Accessors: @reset
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.MD: CreateInput, ExtractCell

(::CreateInput{T})(template::PWInput, cell) where {T} =
    (customizer(cell) ∘ normalizer(T()))(template)

struct CalculationSetter{T} <: Setter
    calculation::T
end
function (setter::CalculationSetter)(template::PWInput)
    if setter.calculation isa IonDynamics  # Functions can be extended, not safe
        @reset template.control.calculation = "md"
    elseif setter.calculation isa VariableCellMolecularDynamics
        @reset template.control.calculation = "vc-md"
        @reset template.ions.ion_dynamics = "beeman"
        @reset template.cell.cell_dynamics = "w"
    else
        throw(ArgumentError("this should never happen!"))
    end
    @reset template.system.nosym = true
    @reset template.ions.pot_extrapolation = "second-order"
    @reset template.ions.wfc_extrapolation = "second-order"
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

function (::ExtractCell)(file)
    str = read(file, String)
    cell_parameters = last(collect(eachcellparameterscard(str)))
    atomic_positions = last(collect(eachatomicpositionscard(str)))
    return Cell(cell_parameters, atomic_positions)
end

customizer(cell::Cell) =
    OutdirSetter("Y-m-d_H:M:S") ∘ CardSetter(CellParametersCard(cell, :bohr)) ∘
    CardSetter(AtomicPositionsCard(cell))
