module EosFitting

using AbInitioSoftwareBase.Inputs: set_verbosity, set_press_vol
using Crystallography: cellvolume
using Dates: format, now
using Distributed: LocalManager
using QuantumESPRESSO.Inputs.PWscf: CellParametersCard, PWInput
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using QuantumESPRESSO.CLI: PWX
using Setfield: @set!
using Unitful: uparse, ustrip, dimension, @u_str
import Unitful
using UnitfulAtomic

using Express: SelfConsistentField
import Express.EosFitting:
    StOptim,
    VcOptim,
    standardize,
    customize,
    check_software_settings,
    expand_settings,
    expandeos,
    shortname,
    parseoutput

const UNIT_CONTEXT = [Unitful, UnitfulAtomic]

function check_software_settings(settings)
    map(("manager", "bin", "n")) do key
        @assert haskey(settings, key)
    end
    @assert isinteger(settings["n"]) && settings["n"] >= 1
    if settings["manager"] == "docker"
        @assert haskey(settings, "container")
    elseif settings["manager"] == "ssh"
    elseif settings["manager"] == "local"  # Do nothing
    else
        error("unknown manager `$(settings["manager"])`!")
    end
end

function _expandtmpl(settings, pressures)  # Can be pressures or volumes
    templates = map(settings) do file
        str = read(expanduser(file), String)
        parse(PWInput, str)
    end
    M, N = length(templates), length(pressures)
    if M == 1
        return fill(first(templates), N)
    elseif M == N
        return templates
    else
        throw(DimensionMismatch("`\"templates\"` should be the same length as `\"pressures\"` or `\"volumes\"`!"))
    end
end

function _expanddirs(settings, pressures_or_volumes)
    prefix = dimension(eltype(pressures_or_volumes)) == dimension(u"Pa") ? "p" : "v"
    return map(pressures_or_volumes) do pressure_or_volume
        abspath(joinpath(expanduser(settings), prefix * string(ustrip(pressure_or_volume))))
    end
end

function expand_settings(settings)
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

    key = haskey(settings, "pressures") ? "pressures" : "volumes"
    pressures_or_volumes = map(settings[key]["values"]) do pressure_or_volume
        pressure_or_volume * uparse(settings[key]["unit"]; unit_context = UNIT_CONTEXT)
    end

    templates = _expandtmpl(settings["templates"], pressures_or_volumes)

    dirs = _expanddirs(settings["workdir"], pressures_or_volumes)

    return (
        templates = templates,
        pressures_or_volumes = pressures_or_volumes,
        trial_eos = expandeos(settings["trial_eos"]),
        dirs = dirs,
        bin = PWX(; bin = bin),
        manager = manager,
        use_shell = settings["use_shell"],
    )
end

shortname(::Type{SelfConsistentField}) = "scf"
shortname(::Type{StOptim}) = "relax"
shortname(::Type{VcOptim}) = "vc-relax"

function standardize(template::PWInput, calc)::PWInput
    @set! template.control.calculation = if calc isa SelfConsistentField  # Functions can be extended, not safe
        "scf"
    elseif calc isa StOptim
        "relax"
    elseif calc isa VcOptim
        "vc-relax"
    else
        error("this should never happen!")
    end
    return set_verbosity(template, "high")
end

function customize(template::PWInput, pressure, eos_or_volume)::PWInput
    @set! template.control.outdir = abspath(mktempdir(
        mkpath(template.control.outdir);
        prefix = template.control.prefix * format(now(), "_Y-m-d_H:M:S_"),
        cleanup = false,
    ))
    return set_press_vol(template, pressure, eos_or_volume)
end

function parseoutput(::SelfConsistentField)
    function (file)
        str = read(file, String)
        preamble = tryparse(Preamble, str)
        e = try
            parse_electrons_energies(str, :converged)
        catch
        end
        if preamble !== nothing && e !== nothing
            return preamble.omega * u"bohr^3" => e.ε[end] * u"Ry"  # volume, energy
        else
            return
        end
    end
end
function parseoutput(::VcOptim)
    function (file)
        str = read(file, String)
        if !isjobdone(str)
            @warn "Job is not finished!"
        end
        x = tryparsefinal(CellParametersCard, str)
        if x !== nothing
            return cellvolume(parsefinal(CellParametersCard, str)) * u"bohr^3" =>
                parse_electrons_energies(str, :converged).ε[end] * u"Ry"  # volume, energy
        else
            return
        end
    end
end

end
