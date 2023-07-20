using AbInitioSoftwareBase: Setter
using Dates: format, now
using EquationsOfStateOfSolids: PressureEquation, Parameters, getparam, vsolve
using ExpressBase: SelfConsistentField, FixedCellOptimization, VariableCellOptimization
using ExpressBase.Files: parentdir
using QuantumESPRESSO.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow: CreateInput, FitEquationOfState
import ExpressBase: RunCmd

function (::CreateInput{T})(template::PWInput, args...) where {T}
    return (customizer(args...) ∘ normalizer(T()))(template)
end

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

function (x::RunCmd)(input, output=mktemp(parentdir(input))[1]; kwargs...)
    return pw(input, output; kwargs...)
end
