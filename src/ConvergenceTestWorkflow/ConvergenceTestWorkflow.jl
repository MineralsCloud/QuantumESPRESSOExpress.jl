module ConvergenceTestWorkflow

using Express: SCF
using QuantumESPRESSO.PWscf: parse_electrons_energies
using Unitful: @u_str
using UnitfulAtomic

import Express.ConvergenceTestWorkflow: parseoutput

include("Config.jl")
include("actions.jl")

function parseoutput(file)
    str = read(file, String)
    return parse_electrons_energies(str, :converged)[end, :ε]
end

end
