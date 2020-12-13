function checkconfig(::QE, config)
    map(("manager", "bin", "n")) do key
        @assert haskey(config, key)
    end
    @assert isinteger(config["n"]) && config["n"] >= 1
    if config["manager"] == "docker"
        @assert haskey(config, "container")
    elseif config["manager"] == "ssh"
    elseif config["manager"] == "local"  # Do nothing
    else
        error("unknown manager `$(config["manager"])`!")
    end
    return
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

function _expanddirs(settings, pressures)
    prefix = dimension(eltype(pressures)) == dimension(u"Pa") ? "p" : "v"
    return map(pressures) do pressure_or_volume
        abspath(joinpath(expanduser(settings), prefix * string(ustrip(pressure_or_volume))))
    end
end

function _materialize_vol(config, templates)
    if haskey(config, "volumes")
        subconfig = config["volumes"]
        unit = uparse(
            if haskey(subconfig, "unit")
                subconfig["unit"]
            else
                @info "no unit provided for `\"volumes\"`! \"bohr^3\" is assumed!"
                u"bohr^3"
            end;
            unit_context = UNIT_CONTEXT,
        )
        return map(Base.Fix1(*, unit), subconfig["values"])
    else
        return map(cellvolume, templates) * u"bohr^3"
    end
end

function materialize(config)
    qe = config["qe"]
    if qe["manager"] == "local"
        bin = qe["bin"]
        manager = LocalManager(qe["n"], true)
    elseif qe["manager"] == "docker"
        n = qe["n"]
        bin = qe["bin"]
        # manager = DockerEnvironment(n, qe["container"], bin)
    else
    end

    pressures = map(config["pressures"]["values"]) do pressure
        pressure * uparse(config["pressures"]["unit"]; unit_context = UNIT_CONTEXT)
    end

    templates = _expandtmpl(config["templates"], pressures)

    if haskey(config, "trial_eos")  # "trial_eos" and "volumes" are mutually exclusive
        trial_eos = materialize_eos(config["trial_eos"])
        volumes = nothing
    else
        trial_eos = nothing
        volumes = _materialize_vol(config, templates)
    end

    dirs = _expanddirs(config["workdir"], pressures)

    return (
        templates = templates,
        pressures = pressures,
        trial_eos = trial_eos,
        volumes = volumes,
        dirs = dirs,
        bin = PWX(; bin = bin),
        manager = manager,
        use_shell = config["use_shell"],
    )
end
