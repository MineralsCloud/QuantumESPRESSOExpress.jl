module EosFitting

using AbInitioSoftwareBase.Inputs: Setter
using Crystallography: cellvolume
using Dates: format, now
using Distributed: LocalManager
using EquationsOfStateOfSolids.Collections: EquationOfStateOfSolids, PressureEOS, getparam
using EquationsOfStateOfSolids.Volume: mustfindvolume
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, PWInput, VerbositySetter, VolumeSetter, PressureSetter
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using QuantumESPRESSO.CLI: PWX
using Setfield: @set!
using Unitful: Pressure, Volume, uparse, ustrip, dimension, @u_str
import Unitful
using UnitfulAtomic

using Express: SelfConsistentField, Optimization
import Express.EosFitting:
    StOptim,
    VcOptim,
    ScfOrOptim,
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

struct CalculationSetter{T<:Union{SelfConsistentField,Optimization}} <: Setter
    calc::T
end
function (::CalculationSetter{T})(template::PWInput) where {T}
    @set! template.control.calculation = if T == SelfConsistentField  # Functions can be extended, not safe
        "scf"
    elseif T == StOptim
        "relax"
    else
        "vc-relax"
    end
    return template
end

function standardize(x::ScfOrOptim)
    function _standardize(template::PWInput)::PWInput
        set = VerbositySetter("high") ∘ CalculationSetter(x)
        return set(template)
    end
end

struct OutdirSetter{T} <: Setter
    timefmt::T
end
OutdirSetter() = OutdirSetter(" Y-m-d H:M:S ")
function (x::OutdirSetter)(template::PWInput)
    @set! template.control.outdir = abspath(joinpath(
        template.control.outdir,
        template.control.prefix * format(now(), x.timefmt),
    ))
    return template
end

customize(a, b) = customize(b, a)  # If no method found, switch arguments & try again
function customize(pressure::Pressure, volume::Volume)
    function _customize(template::PWInput)::PWInput
        set = OutdirSetter() ∘ VolumeSetter(volume) ∘ PressureSetter(pressure)
        return set(template)
    end
end
function customize(pressure::Pressure, eos::PressureEOS)
    function _customize(template::PWInput)::PWInput
        volume = mustfindvolume(eos, pressure; volume_scale = (0.5, 1.5))
        set = OutdirSetter() ∘ VolumeSetter(volume) ∘ PressureSetter(pressure)
        return set(template)
    end
end
customize(pressure::Pressure, eos::EquationOfStateOfSolids) =
    customize(pressure, PressureEOS(getparam(eos)))

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
