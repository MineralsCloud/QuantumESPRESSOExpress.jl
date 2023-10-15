using AbInitioSoftwareBase: Input, Setter
using Dates: format, now
using ExpressBase:
    Calculation,
    SelfConsistentField,
    DensityFunctionalPerturbationTheory,
    RealSpaceForceConstants,
    PhononDispersion,
    VDOS
using QuantumESPRESSO.PWscf:
    PWInput,
    CellParametersCard,
    AtomicPositionsCard,
    CellParametersCardSetter,
    AtomicPositionsCardSetter,
    tryparsefinal
using QuantumESPRESSO.PHonon: PhInput, Q2rInput, MatdynInput, VerbositySetter, relayinfo
using QuantumESPRESSO.Commands: pw, ph, q2r, matdyn
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`

import Express.PhononWorkflow: CreateInput, RunCmd, parsecell

function parsecell(str)
    return tryparsefinal(AtomicPositionsCard, str), tryparsefinal(CellParametersCard, str)
end

function (::CreateInput{SelfConsistentField})(template::PWInput, args...)
    return (customizer(args...) ∘ normalizer(SelfConsistentField(), template))(template)
end
function (::CreateInput{DensityFunctionalPerturbationTheory})(
    template::PhInput, previnp::PWInput
)
    return normalizer(DensityFunctionalPerturbationTheory(), previnp)(template)
end
function (::CreateInput{RealSpaceForceConstants})(template::Q2rInput, previnp::PhInput)
    return normalizer(RealSpaceForceConstants(), previnp)(template)
end
function (::CreateInput{T})(
    template::MatdynInput, a::Q2rInput, b::PhInput
) where {T<:Union{PhononDispersion,VDOS}}
    return normalizer(T(), (a, b))(template)
end

struct CalculationSetter <: Setter
    calc::Union{SelfConsistentField,DensityFunctionalPerturbationTheory}
end
function (::CalculationSetter)(template::PWInput)
    @set! template.control.calculation = "scf"
    return template
end

struct RelayArgumentsSetter <: Setter
    input::Union{Input,Tuple}
end
(x::RelayArgumentsSetter)(template) = relayinfo(x.input, template)
function (x::RelayArgumentsSetter)(template::MatdynInput)
    template = relayinfo(x.input[1], template)
    template = relayinfo(x.input[2], template)
    return template
end

struct DosSetter <: Setter
    dos::Bool
end
function (x::DosSetter)(template::MatdynInput)
    @set! template.input.dos = x.dos
    return template
end

struct RecoverySetter <: Setter end
function (::RecoverySetter)(template::PhInput)
    @set! template.inputph.recover = true
    return template
end

struct PseudoDirSetter <: Setter end
function (x::PseudoDirSetter)(template::PWInput)
    @set! template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

function normalizer(::SelfConsistentField, args...)
    return VerbositySetter("high") ∘ CalculationSetter(SelfConsistentField()) ∘
           PseudoDirSetter()
end
function normalizer(::DensityFunctionalPerturbationTheory, input::PWInput)
    return RelayArgumentsSetter(input) ∘ VerbositySetter("high") ∘ RecoverySetter()
end
normalizer(::RealSpaceForceConstants, input::PhInput) = RelayArgumentsSetter(input)
function normalizer(
    ::PhononDispersion, inputs::Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}}
)
    return RelayArgumentsSetter(inputs) ∘ DosSetter(false)
end
function normalizer(::VDOS, inputs::Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}})
    return RelayArgumentsSetter(inputs) ∘ DosSetter(true)
end

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    # Set `outdir` to `outdir` + a subdirectory.
    @set! template.control.outdir = abspath(
        joinpath(
            template.control.outdir,
            join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
        ),
    )
    if !isdir(template.control.outdir)
        mkpath(template.control.outdir)
    end
    return template
end

customizer(ap::AtomicPositionsCard, cp::CellParametersCard) =
    OutdirSetter("Y-m-d_H:M:S") ∘ CellParametersCardSetter(cp) ∘
    AtomicPositionsCardSetter(ap)

function (x::RunCmd{SelfConsistentField})(
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
function (x::RunCmd{<:Union{VDOS,PhononDispersion}})(
    input, output=mktemp(parentdir(input))[1]; kwargs...
)
    return matdyn(input, output; kwargs...)
end
