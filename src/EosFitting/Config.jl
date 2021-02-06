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

    if config.fixed isa Pressures
        pressures = materialize_press(config.fixed)
        volumes = nothing
    else
        pressures = nothing
        volumes = materialize_vol(config)
    end

    trial_eos = isnothing(config.trial_eos) ? nothing : materialize_eos(config.trial_eos)

    return (
        templates = templates,
        pressures = pressures,
        trial_eos = trial_eos,
        volumes = volumes,
        # workdir = config.workdir,
        dirs = materialize_dir(config),
        bin = config.cli,
    )
end

end
