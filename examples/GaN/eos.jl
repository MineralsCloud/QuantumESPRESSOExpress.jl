using Express: buildworkflow
using QuantumESPRESSOExpress.EosFitting
using SimpleWorkflow: run!

x = buildworkflow("examples/GaN/eos.yaml")
run!(x)
