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
