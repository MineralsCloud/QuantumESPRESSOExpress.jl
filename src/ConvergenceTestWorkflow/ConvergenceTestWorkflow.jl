module ConvergenceTestWorkflow

using Express: Scf
using QuantumESPRESSO.Outputs.PWscf: parse_electrons_energies
using Unitful: @u_str
using UnitfulAtomic

import Express.ConvergenceTestWorkflow: parseoutput

include("Config.jl")
include("actions.jl")

function parseoutput(::Scf)
    function (file)
        str = read(file, String)
        try
            parse_electrons_energies(str, :converged)
        catch
        end
    end
end

end
