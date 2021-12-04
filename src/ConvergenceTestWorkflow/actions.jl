using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter
using Setfield: @set!
using Unitful: ustrip, @u_str
using UnitfulAtomic

import Express.ConvergenceTestWorkflow: MakeInput, RunCmd

(::MakeInput)(template::PWInput, args...) = (customizer(args...) ∘ normalizer())(template)

struct CutoffEnergySetter <: Setter
    wfc::Number
end
function (x::CutoffEnergySetter)(template::PWInput)
    @set! template.system.ecutwfc = ustrip(u"Ry", x.wfc)
    return template
end

normalizer() = VerbositySetter("high")

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    @set! template.control.outdir = abspath(
        joinpath(
            template.control.outdir,
            join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
        ),
    )
    mkpath(template.control.outdir)
    return template
end

customizer(calc, timefmt = "Y-m-d_H:M:S") = OutdirSetter(timefmt) ∘ CutoffEnergySetter(calc)

(x::RunCmd)(input, output = mktemp(parentdir(input))[1]; kwargs...) =
    pw(input, output; kwargs...)
