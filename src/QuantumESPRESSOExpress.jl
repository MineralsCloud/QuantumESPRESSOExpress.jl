module QuantumESPRESSOExpress

using AbInitioSoftwareBase: AbInitioSoftware

import Express: currentsoftware

export QE

struct QuantumESPRESSO <: AbInitioSoftware end
const QE = QuantumESPRESSO

currentsoftware() = QE()

include("EquationOfStateWorkflow/EquationOfStateWorkflow.jl")
include("Phonon/Phonon.jl")

end
