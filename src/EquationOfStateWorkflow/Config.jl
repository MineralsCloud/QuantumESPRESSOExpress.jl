module Config

using Configurations: OptionField
using QuantumESPRESSO.Inputs.PWscf: PWInput
using QuantumESPRESSO.Commands: QuantumESPRESSOConfig, PwxConfig
using AbInitioSoftwareBase.Commands: CommandConfig, MpiexecConfig

import Configurations: from_dict
import Express.EquationOfStateWorkflow.Config: RuntimeConfig, ExpandConfig

function (::ExpandConfig)(template::AbstractString)
    str = read(expanduser(template), String)
    return parse(PWInput, str)
end

function from_dict(::Type{RuntimeConfig}, ::OptionField{:cli}, ::Type{CommandConfig}, dict)
    return QuantumESPRESSOConfig(;
        mpi=get(dict, "mpi", MpiexecConfig()), pw=get(dict, "pw", PwxConfig())
    )
end

end
