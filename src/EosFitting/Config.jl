module Config

using Configurations: from_dict, @option
using Express.EosFitting.Config:
    Pressures,
    EosFittingConfig,
    materialize_eos,
    materialize_press,
    materialize_vol,
    materialize_dir
import Express.EosFitting.Config: materialize
using QuantumESPRESSO.Cli: QuantumESPRESSOCliConfig
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, PWInput, VerbositySetter, VolumeSetter, PressureSetter

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

function materialize(config)
    config = from_dict(EosFittingConfig{QuantumESPRESSOCliConfig}, config)

    templates = _materialize_tmpl(config.templates, config.fixed)

    fixed = if config.fixed isa Pressures
        materialize_press(config.fixed)
    else
        materialize_vol(config)
    end

    return (
        templates = templates,
        fixed = fixed,
        trial_eos = materialize_eos(config.trial_eos),
        workdir = config.workdir,
        dirs = materialize_dir(config),
        cli = config.cli,
    )
end

end
