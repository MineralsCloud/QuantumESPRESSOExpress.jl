using Express: buildworkflow
using QuantumESPRESSOExpress.Phonon
using SimpleWorkflow: run!

x = buildworkflow("examples/GaN/phonon.yaml")
run!(x)
