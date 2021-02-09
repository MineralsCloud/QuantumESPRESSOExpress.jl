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

using ...QuantumESPRESSOExpress: QE

import Express.Phonon: shortname
import Express.Phonon.DefaultActions: parsecell, inputtype

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
