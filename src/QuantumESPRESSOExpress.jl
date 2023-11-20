module QuantumESPRESSOExpress

using AbInitioSoftwareBase: AbInitioSoftware
using ExpressBase:
    SelfConsistentField,
    VariableCellOptimization,
    LinearResponse,
    FourierTransform,
    PhononDispersion,
    PhononDensityOfStates
using ExpressBase.Files: parentdir

# import Express: current_software
import ExpressBase: RunCmd

export QE

struct QuantumESPRESSO <: AbInitioSoftware end
const QE = QuantumESPRESSO

currentsoftware() = QE()

include("SoftwareConfig.jl")
include("ConvergenceTest/ConvergenceTest.jl")
include("MD/MD.jl")
include("EquationOfState/EquationOfState.jl")
include("Phonon/Phonon.jl")

function (x::RunCmd{SelfConsistentField})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return pw(input, output; kwargs...)
end
function (x::RunCmd{VariableCellOptimization})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return pw(input, output; kwargs...)
end
function (x::RunCmd{LinearResponse})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return ph(input, output; kwargs...)
end
function (x::RunCmd{FourierTransform})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return q2r(input, output; kwargs...)
end
function (x::RunCmd{<:Union{PhononDensityOfStates,PhononDispersion}})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return matdyn(input, output; kwargs...)
end

end
