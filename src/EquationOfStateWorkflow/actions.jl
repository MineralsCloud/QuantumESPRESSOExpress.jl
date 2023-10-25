using AbInitioSoftwareBase: Setter
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
    CardSetter
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow: CreateInput, FitEquationOfState

(::CreateInput{T})(template::PWInput, volume_or_cell) where {T} =
    (customizer(volume_or_cell) ∘ normalizer(T()))(template)

struct CalculationSetter{T} <: Setter
    calculation::T
end
function (x::CalculationSetter)(template::PWInput)
    @set! template.control.calculation = if x.calculation isa SelfConsistentField  # Functions can be extended, not safe
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
    @set! template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

normalizer(calculation) =
    VerbositySetter("high") ∘ CalculationSetter(calculation) ∘ PseudoDirSetter()

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    # Set `outdir` to `outdir` + a subdirectory.
    @set! template.control.outdir = abspath(
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
