module Config

using QuantumESPRESSO.Inputs.PWscf: PWInput
using QuantumESPRESSO.Commands:
    QuantumESPRESSOConfig, PwxConfig, PhxConfig, Q2rxConfig, MatdynxConfig
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
        ph = get(dict, "ph", PhxConfig()),
        q2r = get(dict, "q2r", Q2rxConfig()),
        matdyn = get(dict, "matdyn", MatdynxConfig()),
    )

end
