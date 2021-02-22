module Config

using Configurations: from_dict, @option
using Crystallography: cellvolume
using Express.EosFitting.Config: Pressures, Volumes, EosFittingConfig
using QuantumESPRESSO.Cli: QuantumESPRESSOCliConfig
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, PWInput, VerbositySetter, VolumeSetter, PressureSetter

import Express.EosFitting.Config: materialize

function _materialize_tmpl(config, fixed)
    arr = map(config.paths) do file
        str = read(expanduser(file), String)
        parse(PWInput, str)
    end
    if length(arr) != 1  # Length of `templates` = length of `pressures`
        return arr
    else
        return repeat(arr, length(fixed.values))
    end
end

function materialize(config::AbstractDict)
    config = from_dict(EosFittingConfig{QuantumESPRESSOCliConfig}, config)

    templates = _materialize_tmpl(config.templates, config.fixed)

    fixed = if config.fixed === nothing
        # If no volume or pressure is provided, use templates cell volumes
        Volumes(map(cellvolume, config.templates))
    else
        config.fixed
    end |> materialize

    return (
        templates = templates,
        fixed = fixed,
        trial_eos = materialize(config.trial_eos),
        workdir = config.dirs.root,
        dirs = materialize(config.dirs, config.fixed),
        inv_opt = config.inv_opt,
        recover = abspath(expanduser(config.recover)),
        cli = config.cli,
    )
end

end
