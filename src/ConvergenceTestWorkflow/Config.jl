module Config

using QuantumESPRESSO.PWscf: PWInput
using QuantumESPRESSO.Commands: QuantumESPRESSOConfig, PwxConfig

import Configurations: convert_to_option
import Express.ConvergenceTestWorkflow.Config: StaticConfig, ExpandConfig

function (::ExpandConfig)(template::AbstractString)
    str = read(expanduser(template), String)
    return parse(PWInput, str)
end

function convert_to_option(::Type{<:StaticConfig}, ::Type{CommandConfig}, dict)
    return QuantumESPRESSOConfig(;
        mpi=get(dict, "mpi", MpiexecConfig()), pw=get(dict, "pw", PwxConfig())
    )
end

end
