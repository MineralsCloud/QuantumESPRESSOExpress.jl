module Config

using Crystallography: cellvolume
using QuantumESPRESSO.Inputs.PWscf:
    CellParametersCard, PWInput, VerbositySetter, VolumeSetter, PressureSetter

import Express.EquationOfStateWorkflow.Config: materialize

function _materialize_tmpl(config, fixed)
    arr = map(config.paths) do file
        str = read(expanduser(file), String)
        parse(PWInput, str)
    end
    if length(arr) != 1  # Length of `templates` = length of `pressures`
        return arr
    else
        return repeat(arr, length(fixed.values))
    end
end

end
