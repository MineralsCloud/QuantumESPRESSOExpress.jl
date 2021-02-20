module Phonon

using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using Express: Calculation, Scf
using Express.EosFitting: VcOptim
using Express.Phonon: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, StructureSetter
using QuantumESPRESSO.Inputs.PHonon:
    PhInput, Q2rInput, MatdynInput, VerbositySetter, relayinfo
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!

import Express.Phonon: shortname
import Express.Phonon.DefaultActions: parsecell, inputtype

include("Config.jl")

module DefaultActions

using AbInitioSoftwareBase.Inputs: Setter
using AbInitioSoftwareBase.Cli: MpiexecOptions
using Dates: format, now
using Express: Calculation, Scf, loadconfig
using Express.EosFitting: VcOptim
using Express.Phonon: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, StructureSetter
using QuantumESPRESSO.Inputs.PHonon:
    PhInput, Q2rInput, MatdynInput, VerbositySetter, relayinfo
using QuantumESPRESSOCli: PwxConfig, PhxConfig, Q2rxConfig, MatdynxConfig, makecmd
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!
using SimpleWorkflow: ExternalAtomicJob, parallel

using ...QuantumESPRESSOExpress: QE

import Express.Phonon: shortname, buildjob
import Express.Phonon.DefaultActions: MakeInput, MakeCmd, parsecell, inputtype
import Express.Shell: distprocs

include("MakeInput.jl")
include("MakeCmd.jl")

inputtype(x::Calculation) = inputtype(typeof(x))
inputtype(::Type{Scf}) = PWInput
inputtype(::Type{Dfpt}) = PhInput
inputtype(::Type{RealSpaceForceConstants}) = Q2rInput
inputtype(::Type{<:Union{PhononDispersion,VDos}}) = MatdynInput

shortname(::Type{Scf}) = "phscf"
shortname(::Type{VcOptim}) = "vc-relax"
shortname(::Type{Dfpt}) = "dfpt"
shortname(::Type{RealSpaceForceConstants}) = "q2r"
shortname(::Type{PhononDispersion}) = "disp"
shortname(::Type{VDos}) = "vdos"

parsecell(str) =
    tryparsefinal(CellParametersCard, str), tryparsefinal(AtomicPositionsCard, str)

end

end
