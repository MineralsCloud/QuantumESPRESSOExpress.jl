using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Commands: MpiexecConfig
using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.Inputs.PWscf: PWInput, VerbositySetter
using Setfield: @set!

import Express.EquationOfStateWorkflow: MakeInput, FitEos, RunCmd

(::MakeInput)(template::PWInput, args...) = (customizer(args...) ∘ normalizer())(template)

struct CutoffEnergySetter <: Setter
    wfc::Number
end
function (x::CutoffEnergySetter)(template::PWInput)
    @set! template.system.ecutwfc = x.wfc
    return template
end

normalizer(calc::Scf) = VerbositySetter("high") ∘ CutoffEnergySetter(calc)

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

customizer(timefmt = "Y-m-d_H:M:S") = OutdirSetter(timefmt)
