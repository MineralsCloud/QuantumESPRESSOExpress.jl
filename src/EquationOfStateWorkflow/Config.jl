module Config

using QuantumESPRESSO.Inputs.PWscf: PWInput
using QuantumESPRESSO.Commands: QuantumESPRESSOConfig, PwxConfig
using AbInitioSoftwareBase.Commands: CommandConfig, MpiexecConfig

import Configurations: convert_to_option
import Express.EquationOfStateWorkflow.Config: RuntimeConfig, ExpandConfig

function (::ExpandConfig)(template::AbstractString)
    str = read(expanduser(template), String)
    return parse(PWInput, str)
end

convert_to_option(::Type{RuntimeConfig}, ::Type{CommandConfig}, dict) =
    QuantumESPRESSOConfig(;
        mpi = get(dict, "mpi", MpiexecConfig()),
        pw = get(dict, "pw", PwxConfig()),
    )

end
