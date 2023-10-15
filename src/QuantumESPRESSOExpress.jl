module QuantumESPRESSOExpress

using AbInitioSoftwareBase: AbInitioSoftware
using ExpressBase.Files: parentdir

# import Express: current_software
import ExpressBase: RunCmd

export QE

struct QuantumESPRESSO <: AbInitioSoftware end
const QE = QuantumESPRESSO

currentsoftware() = QE()

include("ConvergenceTestWorkflow/ConvergenceTestWorkflow.jl")
include("EquationOfStateWorkflow/EquationOfStateWorkflow.jl")
include("PhononWorkflow/PhononWorkflow.jl")

function (x::RunCmd)(input, output=mktemp(parentdir(input))[1]; kwargs...)
    return pw(input, output; kwargs...)
end

end
