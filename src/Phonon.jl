module Phonon

using AbInitioSoftwareBase.Inputs: inputstring, writeinput, set_verbosity
using Dates: format, now
using Distributed: LocalManager
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, optconvert
using QuantumESPRESSO.Inputs.PHonon: PhInput, Q2rInput, MatdynInput, DynmatInput, relayinfo
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!, @set
using Unitful: @u_str
using UnitfulAtomic

using Express: SelfConsistentField, Scf
using Express.Phonon:
    DensityFunctionalPerturbationTheory,
    Dfpt,
    InteratomicForceConstants,
    Ifc,
    PhononDispersion,
    PhononDensityOfStates,
    VDos,
    makeinput,
    standardize,
    customize
import Express.Phonon: standardize, expand_settings, parsecell, previnputtype, shortname

export DensityFunctionalPerturbationTheory,
    Dfpt,
    SelfConsistentField,
    Scf,
    InteratomicForceConstants,
    Ifc,
    PhononDispersion,
    PhononDensityOfStates,
    VDos,
    standardize,
    makeinput,
    standardize,
    customize


# This is a helper function and should not be exported.
standardize(template::PWInput, ::SelfConsistentField)::PWInput =
    @set(template.control.calculation = "scf")
standardize(template::PhInput, ::Dfpt)::PhInput = @set(template.inputph.verbosity = "high")
standardize(template::Q2rInput, ::Ifc)::Q2rInput = template
standardize(template::MatdynInput, ::PhononDispersion)::MatdynInput =
    @set(template.input.dos = false)
standardize(template::MatdynInput, ::VDos)::MatdynInput = @set(template.input.dos = true)

function customize(template::PWInput, args...)::PWInput
    @set! template.control.outdir = abspath(mktempdir(
        mkpath(template.control.outdir);
        prefix = template.control.prefix * format(now(), "_Y-m-d_H:M:S_"),
        cleanup = false,
    ))
    return set_verbosity(template, "high")
end
customize(template::PhInput, pw::PWInput)::PhInput = relayinfo(pw, template)
customize(template::Q2rInput, ph::PhInput)::Q2rInput = relayinfo(ph, template)
customize(template::MatdynInput, q2r::Q2rInput, ph::PhInput)::MatdynInput =
    relayinfo(q2r, relayinfo(ph, template))

function expand_settings(settings)
    templatetexts = [read(expanduser(f), String) for f in settings["template"]]
    template = parse(PWInput, templatetexts[1]),
    parse(PhInput, templatetexts[2]),
    parse(Q2rInput, templatetexts[3]),
    parse(MatdynInput, templatetexts[4])
    qe = settings["qe"]
    if qe["manager"] == "local"
        bin = qe["bin"]
        manager = LocalManager(qe["n"], true)
    elseif qe["manager"] == "docker"
        n = qe["n"]
        bin = qe["bin"]
        # manager = DockerEnvironment(n, qe["container"], bin)
    else
    end
    return (
        template = template,
        pressures = settings["pressures"] .* u"GPa",
        dirs = map(settings["pressures"]) do pressure
            abspath(joinpath(
                expanduser(settings["dir"]),
                template[1].control.prefix,
                "p" * string(pressure),
            ))
        end,
        bin = bin,
        manager = manager,
    )
end

previnputtype(::Dfpt) = PWInput

shortname(::Scf) = "scf"
shortname(::Dfpt) = "dfpt"
shortname(::PhononDispersion) = "disp"
shortname(::VDos) = "vdos"

parsecell(str) =
    tryparsefinal(CellParametersCard, str), tryparsefinal(AtomicPositionsCard, str)

end
