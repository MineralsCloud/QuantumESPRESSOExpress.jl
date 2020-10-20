module EosFitting

using AbInitioSoftwareBase.Inputs: set_verbosity
using Crystallography: Cell, eachatom, cellvolume
using Dates: format, now
using Distributed: LocalManager
using EquationsOfStateOfSolids.Collections
using Express.EosFitting: set_press_vol
using OptionalArgChecks: @argcheck
using QuantumESPRESSO.Inputs: inputstring, optionof
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, AtomicPositionsCard, PWInput, optconvert
using QuantumESPRESSO.Outputs.PWscf:
    Preamble, parse_electrons_energies, parsefinal, isjobdone, tryparsefinal
using QuantumESPRESSO.CLI: PWCmd
using Setfield: @set!
using Unitful
using UnitfulAtomic

import Express.EosFitting:
    SelfConsistentField,
    VariableCellOptimization,
    standardize,
    customize,
    _check_software_settings,
    _expand_settings,
    _readoutput

export safe_exit

function _check_software_settings(settings)
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

const EosMap = (
    m = Murnaghan,
    bm2 = BirchMurnaghan2nd,
    bm3 = BirchMurnaghan3rd,
    bm4 = BirchMurnaghan4th,
    v = Vinet,
)

function _expand_settings(settings)
    template = parse(PWInput, read(expanduser(settings["template"]), String))
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
        trial_eos = EosMap[Symbol(settings["trial_eos"]["type"])](settings["trial_eos"]["parameters"] .*
                                                                  uparse.(
            settings["trial_eos"]["units"];
            unit_context = [Unitful, UnitfulAtomic],
        )...),
        dirs = map(settings["pressures"]) do pressure
            abspath(joinpath(
                expanduser(settings["dir"]),
                template.control.prefix,
                "p" * string(pressure),
            ))
        end,
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

function _readoutput(::SelfConsistentField, s::AbstractString)
    preamble = tryparse(Preamble, s)
    e = try
        parse_electrons_energies(s, :converged)
    catch
        nothing
    end
    if preamble !== nothing && e !== nothing
        return preamble.omega * u"bohr^3" => e.ε[end] * u"Ry"  # volume, energy
    else
        return
    end
end
function _readoutput(::VariableCellOptimization, s::AbstractString)
    if !isjobdone(s)
        @warn "Job is not finished!"
    end
    x = tryparsefinal(CellParametersCard, s)
    if x !== nothing
        return cellvolume(parsefinal(CellParametersCard, s)) * u"bohr^3" =>
            parse_electrons_energies(s, :converged).ε[end] * u"Ry"  # volume, energy
    else
        return
    end
end

safe_exit(template::PWInput, dir) = touch(joinpath(dir, template.control.prefix * ".EXIT"))

end
