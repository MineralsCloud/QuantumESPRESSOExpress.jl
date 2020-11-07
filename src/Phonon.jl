module Phonon

using Dates: format, now
using Distributed: LocalManager
using QuantumESPRESSO.CLI: PhCmd, PWCmd
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, optconvert, set_verbosity, set_cell
using QuantumESPRESSO.Inputs.PHonon: PhInput, Q2rInput, MatdynInput, DynmatInput, relayinfo
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!, @set
using Unitful: uparse, ustrip, @u_str
import Unitful
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

const UNIT_CONTEXT = [Unitful, UnitfulAtomic]

# This is a helper function and should not be exported.
standardize(template::PWInput, ::SelfConsistentField)::PWInput =
    @set(template.control.calculation = "scf")
standardize(template::PhInput, ::Dfpt)::PhInput = @set(template.inputph.verbosity = "high")
standardize(template::Q2rInput, ::Ifc)::Q2rInput = template
standardize(template::MatdynInput, ::PhononDispersion)::MatdynInput =
    @set(template.input.dos = false)
standardize(template::MatdynInput, ::VDos)::MatdynInput = @set(template.input.dos = true)

function customize(template::PWInput, new_structure)::PWInput
    @set! template.control.outdir = abspath(mktempdir(
        mkpath(template.control.outdir);
        prefix = template.control.prefix * format(now(), "_Y-m-d_H:M:S_"),
        cleanup = false,
    ))
    template = set_cell(template, new_structure...)
    template = set_verbosity(template, "high")
    return template
end
customize(template::PhInput, pw::PWInput)::PhInput = relayinfo(pw, template)
customize(template::Q2rInput, ph::PhInput)::Q2rInput = relayinfo(ph, template)
customize(template::MatdynInput, q2r::Q2rInput, ph::PhInput)::MatdynInput =
    relayinfo(q2r, relayinfo(ph, template))

function expand_settings(settings)
    pressures = map(settings["pressures"]["values"]) do pressure
        pressure * uparse(settings["pressures"]["unit"]; unit_context = UNIT_CONTEXT)
    end

    function expandtmpl(settings)
        return map(settings, (PWInput, PhInput, Q2rInput, MatdynInput)) do file, T
            str = read(expanduser(file), String)
            parse(T, str)
        end
    end
    templates = expandtmpl(settings["templates"])

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

    function expanddirs(settings)
        return map(pressures, templates) do pressure, template
            abspath(joinpath(
                expanduser(settings["workdir"]),
                "p=" * string(ustrip(pressure)),
            ))
        end
    end
    dirs = expanddirs(settings)

    return (
        templates = templates,
        pressures = pressures,
        dirs = dirs,
        bin = PWCmd(; bin = bin),
        manager = manager,
    )
end

previnputtype(::SelfConsistentField) = PWInput
previnputtype(::Dfpt) = PWInput

shortname(::Scf) = "scf"
shortname(::Dfpt) = "dfpt"
shortname(::PhononDispersion) = "disp"
shortname(::VDos) = "vdos"

parsecell(str) =
    tryparsefinal(CellParametersCard, str), tryparsefinal(AtomicPositionsCard, str)

end
