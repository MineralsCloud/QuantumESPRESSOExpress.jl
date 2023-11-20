module QuantumESPRESSOExpress

using AbInitioSoftwareBase: AbInitioSoftware
using ExpressBase:
    SelfConsistentField,
    VariableCellOptimization,
    DensityFunctionalPerturbationTheory,
    RealSpaceForceConstants,
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
include("EquationOfStateWorkflow/EquationOfStateWorkflow.jl")
include("PhononWorkflow/PhononWorkflow.jl")

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
function (x::RunCmd{DensityFunctionalPerturbationTheory})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return ph(input, output; kwargs...)
end
function (x::RunCmd{RealSpaceForceConstants})(
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
