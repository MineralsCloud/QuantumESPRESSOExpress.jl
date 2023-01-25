module QuantumESPRESSOExpress

using AbInitioSoftwareBase: AbInitioSoftware

# import Express: current_software

export QE

struct QuantumESPRESSO <: AbInitioSoftware end
const QE = QuantumESPRESSO

currentsoftware() = QE()

# include("ConvergenceTestWorkflow/ConvergenceTestWorkflow.jl")
include("EquationOfStateWorkflow/EquationOfStateWorkflow.jl")
include("PhononWorkflow/PhononWorkflow.jl")

end
