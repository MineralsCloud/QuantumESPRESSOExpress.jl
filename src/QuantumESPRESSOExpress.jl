module QuantumESPRESSOExpress

using AbInitioSoftwareBase: AbInitioSoftware

import Express: current_software

export QE

struct QuantumESPRESSO <: AbInitioSoftware end
const QE = QuantumESPRESSO

currentsoftware() = QE()

include("EquationOfStateWorkflow/EquationOfStateWorkflow.jl")
# include("Phonon/Phonon.jl")

end
