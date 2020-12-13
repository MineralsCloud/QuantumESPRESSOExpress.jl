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

    dirs = _expanddirs(config["workdir"], pressures_or_volumes)

    return (
        templates = templates,
        pressures_or_volumes = pressures,
        trial_eos = materialize_eos(config["trial_eos"]),
        dirs = dirs,
        bin = PWX(; bin = bin),
        manager = manager,
        use_shell = config["use_shell"],
    )
end
