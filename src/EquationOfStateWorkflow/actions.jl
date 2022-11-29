using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using EquationsOfStateOfSolids: PressureEquation, Parameters, getparam, vsolve
using ExpressBase: Scf, FixedCellOptimization, VariableCellOptimization
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow: MakeInput, FitEos, RunCmd

function (::MakeInput{T})(template::PWInput, args...) where {T}
    return (customizer(args...) ∘ normalizer(T()))(template)
end

struct CalculationSetter{T} <: Setter
    calc::T
end
function (x::CalculationSetter)(template::PWInput)
    @set! template.control.calculation = if x.calc isa Scf  # Functions can be extended, not safe
        "scf"
    elseif x.calc isa FixedCellOptimization
        "relax"
    else
        "vc-relax"
    end
    return template
end

struct PseudodirSetter <: Setter end
function (x::PseudodirSetter)(template::PWInput)
    @set! template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

normalizer(calc) = VerbositySetter("high") ∘ CalculationSetter(calc) ∘ PseudodirSetter()

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

function customizer(volume::Volume, timefmt="Y-m-d_H:M:S")
    return OutdirSetter(timefmt) ∘ VolumeSetter(volume)
end
function customizer(pressure::Pressure, eos::PressureEquation, timefmt="Y-m-d_H:M:S")
    possible_volumes = vsolve(eos, pressure)
    volume = if length(possible_volumes) > 1
        _choose(possible_volumes, pressure, eos)
    else
        only(possible_volumes)
    end
    return OutdirSetter(timefmt) ∘ PressureSetter(pressure) ∘ VolumeSetter(volume)
end
function customizer(pressure::Pressure, params::Parameters, timefmt="Y-m-d_H:M:S")
    return customizer(pressure, PressureEquation(params), timefmt)
end

function (x::RunCmd)(input, output=mktemp(parentdir(input))[1]; kwargs...)
    return pw(input, output; kwargs...)
end

function _choose(possible_volumes, pressure, eos)
    v0 = getparam(eos).v0
    filtered = if pressure >= zero(pressure)  # If pressure is greater than zero,
        filter(<=(v0), possible_volumes)  # the volume could only be smaller than `v0`.
    else
        filter(v -> 1 < v / v0 <= 3, possible_volumes)
    end
    return only(filtered)
end
