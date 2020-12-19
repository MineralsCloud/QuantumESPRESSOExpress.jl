module Phonon

using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using Distributed: LocalManager
using QuantumESPRESSO.CLI: PhX, PWX, Q2rX, MatdynX
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, StructureSetter
using QuantumESPRESSO.Inputs.PHonon:
    PhInput, Q2rInput, MatdynInput, VerbositySetter, relayinfo
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!, @set
using Unitful: uparse, ustrip, @u_str
import Unitful
using UnitfulAtomic

using Express: Scf, _uparse
using Express.EosFitting: VcOptim
using Express.Phonon: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
import Express.Phonon:
    standardize, customize, expand_settings, parsecell, inputtype, shortname

include("normalizer.jl")
include("customizer.jl")

adjust(template::PWInput, x::Scf, args...) = (Customizer(args...) ∘ Normalizer(x))(template)
adjust(template::PhInput, x::Dfpt, args...) =
    (Customizer(args...) ∘ Normalizer(x))(template)

function expand_settings(settings)
    pressures = map(settings["pressures"]["values"]) do pressure
        pressure * _uparse(settings["pressures"]["unit"])
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
        use_shell = settings["use_shell"],
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
