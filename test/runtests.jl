using QuantumESPRESSOExpress
using Test

@testset "QuantumESPRESSOExpress.jl" begin
    include("EquationOfStateWorkflow.jl")
    include("PhononWorkflow.jl")
end
