module Config

using Configurations: from_dict
using Express: myuparse
using Express.Phonon: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
using QuantumESPRESSO.Cli: QuantumESPRESSOCliConfig
using QuantumESPRESSO.Inputs.PWscf: PWInput
using QuantumESPRESSO.Inputs.PHonon: PhInput, Q2rInput, MatdynInput
using Unitful: ustrip

using Express.Phonon.Config: Pressures, Volumes, PhononConfig, DfptTemplate
import Express.Phonon.Config: materialize

function _materialize_tmpl(
    templates::AbstractArray{DfptTemplate},
    fixed::Union{Pressures,Volumes},
)
    results = map(templates) do template
        arr = map(
            (:scf, :dfpt, :q2r, :disp),
            (PWInput, PhInput, Q2rInput, MatdynInput),
        ) do field, T
            str = read(getproperty(template, field), String)
            parse(T, str)
        end
        (; zip((:scf, :dfpt, :q2r, :disp), arr)...)
    end
    if length(results) != 1  # Length of `templates` = length of `pressures`
        return results
    else
        return repeat(results, length(fixed.values))
    end
end

function materialize(config::AbstractDict)
    config = from_dict(PhononConfig{QuantumESPRESSOCliConfig}, config)

    templates = _materialize_tmpl(config.templates, config.fixed)

    return (
        templates = templates,
        fixed = materialize(config.fixed),
        workdir = config.dirs.root,
        dirs = materialize(config.dirs, config.fixed),
        recover = abspath(expanduser(config.recover)),
        cli = config.cli,
    )
end

end
