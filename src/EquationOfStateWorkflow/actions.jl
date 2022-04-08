using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Commands: MpiexecConfig
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using EquationsOfStateOfSolids:
    EquationOfStateOfSolids, PressureEquation, Parameters, getparam, vsolve
using Express.EquationOfStateWorkflow: StOptim, ScfOrOptim
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter, VolumeSetter, PressureSetter
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: Pressure, Volume, @u_str
using UnitfulAtomic

import Express.EquationOfStateWorkflow: MakeInput, FitEos, RunCmd

(::MakeInput{T})(template::PWInput, args...) where {T<:ScfOrOptim} =
    (customizer(args...) ∘ normalizer(T()))(template)

struct CalculationSetter <: Setter
    calc::ScfOrOptim
end
function (x::CalculationSetter)(template::PWInput)
    @set! template.control.calculation = if x.calc isa Scf  # Functions can be extended, not safe
        "scf"
    elseif x.calc isa StOptim
        "relax"
    else
        "vc-relax"
    end
    return template
end

normalizer(calc::ScfOrOptim) = VerbositySetter("high") ∘ CalculationSetter(calc)

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    # If an absolute path is given, then do nothing; else,
    # set `outdir` to the current directory + `outdir` + a subdirectory.
    @set! template.control.outdir = if !isabspath(template.control.outdir)
        abspath(
            joinpath(
                template.control.outdir,
                join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
            ),
        )
    end
    if !isdir(template.control.outdir)
        mkpath(template.control.outdir)
    end
    return template
end

customizer(volume::Volume, timefmt = "Y-m-d_H:M:S") =
    OutdirSetter(timefmt) ∘ VolumeSetter(volume)
function customizer(eos::PressureEquation, pressure::Pressure, timefmt = "Y-m-d_H:M:S")
    possible_volumes = vsolve(eos, pressure)
    volume =
        length(possible_volumes) > 1 ? _choose(possible_volumes, pressure, eos) :
        only(possible_volumes)
    return OutdirSetter(timefmt) ∘ PressureSetter(pressure) ∘ VolumeSetter(volume)
end
customizer(params::Parameters, pressure::Pressure, timefmt = "Y-m-d_H:M:S") =
    customizer(PressureEquation(params), pressure, timefmt)

(x::RunCmd)(input, output = mktemp(parentdir(input))[1]; kwargs...) =
    pw(input, output; kwargs...)

function _choose(possible_volumes, pressure, eos)
    v0 = getparam(eos).v0
    filtered = if pressure >= zero(pressure)  # If pressure is greater than zero,
        filter(<=(v0), possible_volumes)  # the volume could only be smaller than `v0`.
    else
        filter(v -> 1 < v / v0 <= 3, possible_volumes)
    end
    return only(filtered)
end
