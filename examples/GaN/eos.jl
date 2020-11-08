using QuantumESPRESSOExpress.EosFitting: buildworkflow
using SimpleWorkflow: run!

x = buildworkflow("examples/GaN/eos.yaml")
run!(x)
