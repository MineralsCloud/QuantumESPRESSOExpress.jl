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
    templates = map(config) do file
        str = read(expanduser(file), String)
        parse(PWInput, str)
    end
    M, N = length(templates), length(pressures)
    if templates isa Vector  # Length of `templates` = length of `pressures`
        return templates
    else  # `templates` is a single file
        return fill(templates, length(pressures))
    end
end

function _materialize_dirs(config, pressures)
    return map(pressures) do pressure
        abspath(joinpath(expanduser(config), "p" * string(ustrip(pressure))))
    end
end

function _materialize_press(config)
    unit = uparse(
        if haskey(config, "unit")
            config["unit"]
        else
            @info "no unit provided for `\"pressures\"`! \"GPa\" is assumed!"
            u"GPa"
        end;
        unit_context = UNIT_CONTEXT,
    )
    return map(Base.Fix1(*, unit), config["values"])
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

    pressures = _materialize_press(config["pressures"])

    templates = _materialize_tmpl(config["templates"], pressures)

    if haskey(config, "trial_eos")  # "trial_eos" and "volumes" are mutually exclusive
        trial_eos = materialize_eos(config["trial_eos"])
        volumes = nothing
    else
        trial_eos = nothing
        volumes = _materialize_vol(config, templates)
    end

    dirs = _materialize_dirs(config["workdir"], pressures)

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
