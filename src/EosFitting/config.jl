function checkconfig(::QE, config)
    @assert haskey(config, "qe")
    # if config["manager"] == "docker"
    #     @assert haskey(config, "container")
    # elseif config["manager"] == "ssh"
    # elseif config["manager"] == "local"  # Do nothing
    # else
    #     error("unknown manager `$(config["manager"])`!")
    # end
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
    manager = LocalManager(config["np"], true)
    bin = PWExec(; bin = first(config["bin"]["qe"]))

    pressures = materialize_press(config["pressures"])

    templates = _materialize_tmpl(config["templates"], pressures)

    if haskey(config, "trial_eos")  # "trial_eos" and "volumes" are mutually exclusive
        trial_eos = materialize_eos(config["trial_eos"])
        volumes = nothing
    else
        trial_eos = nothing
        volumes = materialize_vol(config, templates)
    end

    workdir = config["workdir"]

    return (
        templates = templates,
        pressures = pressures,
        trial_eos = trial_eos,
        volumes = volumes,
        workdir = workdir,
        dirs = materialize_dirs(workdir, pressures),
        bin = bin,
        manager = manager,
        use_shell = config["use_shell"],
    )
end
