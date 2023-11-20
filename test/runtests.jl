using QuantumESPRESSOExpress
using Test

@testset "QuantumESPRESSOExpress.jl" begin
    include("EquationOfState.jl")
    include("Phonon.jl")
end
