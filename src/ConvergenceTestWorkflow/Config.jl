module Config

using Configurations: OptionField, @option
using ExpressBase.Config: SoftwareConfig
using QuantumESPRESSO.PWscf: PWInput

import Configurations: from_dict
import Express.ConvergenceTestWorkflow.Config: StaticConfig, _update!

function (::ExpandConfig)(template::AbstractString)
    str = read(expanduser(template), String)
    return parse(PWInput, str)
end

function convert_to_option(::Type{<:StaticConfig}, ::Type{SoftwareConfig}, dict)
    return QuantumESPRESSOConfig(;
        mpi=get(dict, "mpi", MpiexecConfig()), pw=get(dict, "pw", PwxConfig())
    )
end

end
