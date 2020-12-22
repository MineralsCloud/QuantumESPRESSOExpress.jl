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

function materialize(config)
    pressures = map(config["pressures"]["values"]) do pressure
        pressure * myuparse(config["pressures"]["unit"])
    end

    function expandtmpl(settings)
        return map(settings, (PWInput, PhInput, Q2rInput, MatdynInput)) do files, T
            temps = map(files) do file
                str = read(expanduser(file), String)
                parse(T, str)
            end
            if length(temps) == 1
                fill(temps[1], length(pressures))
            elseif length(temps) != length(pressures)
                throw(DimensionMismatch("!!!"))
            else
                temps
            end
        end
    end
    templates = expandtmpl(config["templates"])

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

    dirs = map(pressures) do pressure
        abspath(joinpath(config["workdir"], "p" * string(ustrip(pressure))))
    end

    return (
        templates = templates,
        pressures = pressures,
        dirs = dirs,
        bin = [
            PWX(bin = bin[1]),
            PhX(bin = bin[2]),
            Q2rX(bin = bin[3]),
            MatdynX(bin = bin[4]),
        ],
        manager = manager,
        use_shell = config["use_shell"],
    )
end
