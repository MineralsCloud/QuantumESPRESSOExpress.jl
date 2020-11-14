module Phonon

using Dates: format, now
using Distributed: LocalManager
using QuantumESPRESSO.CLI: PhX, PWX, Q2rX, MatdynX
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, set_verbosity, set_cell
using QuantumESPRESSO.Inputs.PHonon: PhInput, Q2rInput, MatdynInput, relayinfo
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!, @set
using Unitful: uparse, ustrip, @u_str
import Unitful
using UnitfulAtomic

using Express: SelfConsistentField
using Express.EosFitting: VcOptim
using Express.Phonon: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
import Express.Phonon:
    standardize, customize, expand_settings, parsecell, inputtype, shortname

const UNIT_CONTEXT = [Unitful, UnitfulAtomic]

# This is a helper function and should not be exported.
standardize(template::PWInput, ::SelfConsistentField)::PWInput =
    @set(template.control.calculation = "scf")
standardize(template::PhInput, ::Dfpt)::PhInput = @set(template.inputph.verbosity = "high")
standardize(template::Q2rInput, ::RealSpaceForceConstants)::Q2rInput = template
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
customize(template::PWInput) = template
customize(template::PhInput, pw::PWInput)::PhInput = relayinfo(pw, template)
customize(template::Q2rInput, ph::PhInput)::Q2rInput = relayinfo(ph, template)
customize(template::MatdynInput, q2r::Q2rInput, ph::PhInput)::MatdynInput =
    relayinfo(q2r, relayinfo(ph, template))
customize(template::MatdynInput, ph::PhInput, q2r::Q2rInput) = customize(template, q2r, ph)

function expand_settings(settings)
    pressures = map(settings["pressures"]["values"]) do pressure
        pressure * uparse(settings["pressures"]["unit"]; unit_context = UNIT_CONTEXT)
    end

    function expandtmpl(settings)
        return map(settings, (PWInput, PhInput, Q2rInput, MatdynInput)) do files, T
            temps = map(files) do file
                str = read(expanduser(file), String)
                parse(T, str)
            end
            if length(temps) == 1
                fill(temps[1], length(pressures))
            elseif length(temps) != length(pressures)
                throw(DimensionMismatch("!!!"))
            else
                temps
            end
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
        return map(pressures) do pressure
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
        bin = [
            PWX(bin = bin[1]),
            PhX(bin = bin[2]),
            Q2rX(bin = bin[3]),
            MatdynX(bin = bin[4]),
        ],
        manager = manager,
    )
end

inputtype(::SelfConsistentField) = PWInput
inputtype(::Dfpt) = PhInput
inputtype(::RealSpaceForceConstants) = Q2rInput
inputtype(::Union{PhononDispersion,VDos}) = MatdynInput

shortname(::Type{SelfConsistentField}) = "phscf"
shortname(::Type{VcOptim}) = "vc-relax"
shortname(::Type{Dfpt}) = "dfpt"
shortname(::Type{RealSpaceForceConstants}) = "q2r"
shortname(::Type{PhononDispersion}) = "disp"
shortname(::Type{VDos}) = "vdos"

parsecell(str) =
    tryparsefinal(CellParametersCard, str), tryparsefinal(AtomicPositionsCard, str)

end
