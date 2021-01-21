module Phonon

using AbInitioSoftwareBase.Inputs: Setter
using Dates: format, now
using Distributed: LocalManager
using Express: Calculation, Scf, myuparse
using Express.EosFitting: VcOptim
using Express.Phonon: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
using QuantumESPRESSO.CLI: PhExec, PWExec, Q2rExec, MatdynExec
using QuantumESPRESSO.Inputs.PWscf:
    AtomicPositionsCard, CellParametersCard, PWInput, StructureSetter
using QuantumESPRESSO.Inputs.PHonon:
    PhInput, Q2rInput, MatdynInput, VerbositySetter, relayinfo
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!, @set
using Unitful: uparse, ustrip, @u_str
import Unitful
using UnitfulAtomic

using ..QuantumESPRESSOExpress: QE

import Express.Phonon: materialize, shortname, checkconfig
import Express.Phonon.DefaultActions: adjust, parsecell, inputtype

include("normalizer.jl")
include("customizer.jl")

adjust(template::PWInput, x::Scf, args...) =
    (Customizer(args...) ∘ Normalizer(x, template))(template)
adjust(template::PhInput, x::Dfpt, previnp::PWInput) = Normalizer(x, previnp)(template)
adjust(template::Q2rInput, x::RealSpaceForceConstants, previnp::PhInput) =
    Normalizer(x, previnp)(template)
adjust(template::MatdynInput, x::Union{PhononDispersion,VDos}, a::Q2rInput, b::PhInput) =
    Normalizer(x, (a, b))(template)
adjust(template::MatdynInput, x::Union{PhononDispersion,VDos}, a::PhInput, b::Q2rInput) =
    adjust(template, x, b, a)

include("config.jl")

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
