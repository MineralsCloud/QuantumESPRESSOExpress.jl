module Config

using AbInitioSoftwareBase.Commands: CommandConfig, MpiexecConfig
using Configurations: from_dict
using Express: myuparse
using Express.PhononWorkflow: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
using QuantumESPRESSO.Commands:
    QuantumESPRESSOConfig, PwxConfig, PhxConfig, Q2rxConfig, MatdynxConfig
    using QuantumESPRESSO.Inputs.PWscf: PWInput
using QuantumESPRESSO.Inputs.PHonon: PhInput, Q2rInput, MatdynInput
using Express.PhononWorkflow.Config: RuntimeConfig, Template

import Configurations: convert_to_option
import Express.PhononWorkflow.Config: ExpandConfig

function (::ExpandConfig)(template::Template)
    inputs = map(
        (:scf, :dfpt, :q2r, :disp),
        (PWInput, PhInput, Q2rInput, MatdynInput),
    ) do field, T
        str = read(getproperty(template, field), String)
        parse(T, str)
    end
    return (; zip((:scf, :dfpt, :q2r, :disp), inputs)...)
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
