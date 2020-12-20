
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

    function expanddirs(settings)
        return map(pressures) do pressure
            abspath(joinpath(
                expanduser(settings["workdir"]),
                "p=" * string(ustrip(pressure)),
            ))
        end
    end
    dirs = expanddirs(config)

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
