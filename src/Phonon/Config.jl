module Config

using Configurations: OptionField
using Express.Phonon.Config: StaticConfig
using ExpressBase:
    SelfConsistentField,
    LinearResponse,
    FourierTransform,
    PhononDispersion,
    PhononDensityOfStates
using ExpressBase.Config: SoftwareConfig
using QuantumESPRESSO.PWscf: PWInput
using QuantumESPRESSO.PHonon: PhInput, Q2rInput, MatdynInput

using ...QuantumESPRESSOExpress:
    MpiexecConfig, QuantumESPRESSOConfig, PwxConfig, PhxConfig, Q2rxConfig, MatdynxConfig

import Configurations: from_dict
import Express.Phonon.Config: StaticConfig, _update!

function _update!(conf, templates::Vector{String})
    stage, T = if conf.calculation isa SelfConsistentField
        1, PWInput
    elseif conf.calculation isa LinearResponse
        2, PhInput
    elseif conf.calculation isa FourierTransform
        3, Q2rInput
    elseif conf.calculation isa PhononDispersion
        4, MatdynInput
    elseif conf.calculation isa PhononDensityOfStates
        4, MatdynInput
    else
        4, DynmatInput
    end
    str = read(templates[stage], String)
    conf.template = parse(T, str)
    return conf
end

function from_dict(
    ::Type{<:StaticConfig}, ::OptionField{:cli}, ::Type{SoftwareConfig}, dict
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
