module Config

using AbInitioSoftwareBase.Commands: MpiexecConfig, CommandConfig
using Configurations: OptionField
using Express.PhononWorkflow.Config: RuntimeConfig, Template
using ExpressBase: CommandConfig
using QuantumESPRESSO.Commands:
    QuantumESPRESSOConfig, PwxConfig, PhxConfig, Q2rxConfig, MatdynxConfig
using QuantumESPRESSO.PWscf: PWInput
using QuantumESPRESSO.PHonon: PhInput, Q2rInput, MatdynInput

import Configurations: from_dict
import Express.PhononWorkflow.Config: ExpandConfig

function (::ExpandConfig)(template::Template)
    inputs = map(
        (:scf, :dfpt, :q2r, :disp), (PWInput, PhInput, Q2rInput, MatdynInput)
    ) do field, T
        str = read(getproperty(template, field), String)
        parse(T, str)
    end
    return (; zip((:scf, :dfpt, :q2r, :disp), inputs)...)
end

function from_dict(
    ::Type{RuntimeConfig}, ::OptionField{:cli}, ::Type{<:CommandConfig}, dict
)
    return from_dict(RuntimeConfig, OptionField{:cli}(), QuantumESPRESSOConfig, dict)
end
function from_dict(
    ::Type{RuntimeConfig}, ::OptionField{:cli}, ::Type{QuantumESPRESSOConfig}, dict
)
    return QuantumESPRESSOConfig(;
        mpi=get(dict, "mpi", MpiexecConfig()),
        pw=get(dict, "pw", PwxConfig()),
        ph=get(dict, "ph", PhxConfig()),
        q2r=get(dict, "q2r", Q2rxConfig()),
        matdyn=get(dict, "matdyn", MatdynxConfig()),
    )
end

end
