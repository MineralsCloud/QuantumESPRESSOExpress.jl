module Config

using QuantumESPRESSO.Inputs.PWscf: PWInput

import Express.EquationOfStateWorkflow.Config: materialize

function materialize(template::AbstractString)
    str = read(expanduser(template), String)
    return parse(PWInput, str)
end

end
