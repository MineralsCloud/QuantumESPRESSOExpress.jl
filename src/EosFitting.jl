module EosFitting

using AbInitioSoftwareBase.Inputs: set_verbosity, set_press_vol
using Crystallography: Cell, eachatom, cellvolume
using Dates: format, now
using Distributed: LocalManager
using EquationsOfStateOfSolids.Collections
using OptionalArgChecks: @argcheck
using QuantumESPRESSO.Inputs: inputstring, optionof
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, AtomicPositionsCard, PWInput, optconvert
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using QuantumESPRESSO.CLI: PWCmd
using Setfield: @set!
import Unitful
using Unitful: uparse, @u_str
using UnitfulAtomic

import Express.EosFitting:
    SelfConsistentField,
    VariableCellOptimization,
    standardize,
    customize,
    check_software_settings,
    expand,
    makeinput,
    parseoutput

export SelfConsistentField,
    VariableCellOptimization,
    standardize,
    customize,
    check_software_settings,
    expand,
    makeinput,
    parseoutput

const UNIT_CONTEXT = [Unitful, UnitfulAtomic]

function check_software_settings(settings)
    map(("manager", "bin", "n")) do key
        @argcheck haskey(settings, key)
    end
    @argcheck isinteger(settings["n"]) && settings["n"] >= 1
    if settings["manager"] == "docker"
        @argcheck haskey(settings, "container")
    elseif settings["manager"] == "ssh"
    elseif settings["manager"] == "local"  # Do nothing
    else
        error("unknown manager `$(settings["manager"])`!")
    end
end

function expandeos(settings)
    type = string(lowercase(settings["type"]))
    T = if type in ("m", "murnaghan")
        Murnaghan
    elseif type in ("bm2", "birchmurnaghan2nd", "birch-murnaghan-2")
        BirchMurnaghan2nd
    elseif type in ("bm3", "birchmurnaghan3rd", "birch-murnaghan-3")
        BirchMurnaghan3rd
    elseif type in ("bm4", "birchmurnaghan4th", "birch-murnaghan-4")
        BirchMurnaghan4th
    elseif type in ("v", "vinet")
        Vinet
    end
    p = map(settings["parameters"]) do x
        @assert length(x) == 2
        first(x) * uparse(last(x); unit_context = UNIT_CONTEXT)
    end
    return T(p...)
end

function expand(settings)
    pressures = map(settings["pressures"]["values"]) do pressure
        pressure * uparse(settings["pressures"]["unit"]; unit_context = UNIT_CONTEXT)
    end

    function expandtmpl(settings)
        templates = map(settings) do file
            str = read(expanduser(file), String)
            parse(PWInput, str)
        end
        if length(templates) == 1
            return fill(first(templates), length(pressures))
        else
            return templates
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
                template.control.prefix * format(now(), "_Y-m-d_H:M_"),
                "p=" * string(pressure),
            ))
        end
    end
    dirs = expanddirs(settings)

    return (
        templates = templates,
        pressures = pressures,
        trial_eos = expandeos(settings["trial_eos"]),
        dirs = dirs,
        bin = PWCmd(; bin = bin),
        manager = manager,
    )
end

_shortname(::SelfConsistentField) = "scf"
_shortname(::VariableCellOptimization) = "vc-relax"

function standardize(template::PWInput, calc)::PWInput
    @set! template.control.calculation = _shortname(calc)
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

function parseoutput(str::AbstractString, ::SelfConsistentField)
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
function parseoutput(str::AbstractString, ::VariableCellOptimization)
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

safe_exit(template::PWInput, dir) = touch(joinpath(dir, template.control.prefix * ".EXIT"))

end
