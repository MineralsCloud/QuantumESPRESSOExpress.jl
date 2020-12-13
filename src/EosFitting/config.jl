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

function _materialize_tmpl(config, pressures)
    arr = map(config) do file
        str = read(expanduser(file), String)
        parse(PWInput, str)
    end
    if length(arr) != 1  # Length of `templates` = length of `pressures`
        return arr
    else
        return repeat(arr, length(pressures))
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

    pressures = materialize_press(config["pressures"])

    templates = _materialize_tmpl(config["templates"], pressures)

    if haskey(config, "trial_eos")  # "trial_eos" and "volumes" are mutually exclusive
        trial_eos = materialize_eos(config["trial_eos"])
        volumes = nothing
    else
        trial_eos = nothing
        volumes = materialize_vol(config, templates)
    end

    dirs = materialize_dirs(config["workdir"], pressures)

    return (
        templates = templates,
        pressures = pressures,
        trial_eos = trial_eos,
        volumes = volumes,
        workdir = config["workdir"],
        dirs = dirs,
        bin = PWX(; bin = bin),
        manager = manager,
        use_shell = config["use_shell"],
    )
end
