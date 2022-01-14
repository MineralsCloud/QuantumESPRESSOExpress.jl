using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Inputs: Setter, Input
using AbInitioSoftwareBase.Commands: MpiexecConfig
using Dates: format, now
using Express: Calculation, Scf
using Express.EquationOfStateWorkflow: VcOptim
using Express.PhononWorkflow: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
# using QuantumESPRESSO.Inputs: QuantumESPRESSOInput
using QuantumESPRESSO.Inputs.PWscf:
    PWInput,
    CellParametersCard,
    AtomicPositionsCard,
    CellParametersCardSetter,
    AtomicPositionsCardSetter
using QuantumESPRESSO.Inputs.PHonon:
    PhInput, Q2rInput, MatdynInput, VerbositySetter, relayinfo
using QuantumESPRESSO.Commands: pw, ph, q2r, matdyn
using QuantumESPRESSO.Outputs.PWscf: tryparsefinal
using Setfield: @set!

import Express.PhononWorkflow:
    MakeInput, RunCmd, parsecell, inputtype, buildjob, getpseudodir, getpotentials
import Express.Shell: distprocs

inputtype(x::Calculation) = inputtype(typeof(x))
inputtype(::Type{Scf}) = PWInput
inputtype(::Type{Dfpt}) = PhInput
inputtype(::Type{RealSpaceForceConstants}) = Q2rInput
inputtype(::Type{<:Union{PhononDispersion,VDos}}) = MatdynInput

parsecell(str) =
    tryparsefinal(AtomicPositionsCard, str), tryparsefinal(CellParametersCard, str)

(::MakeInput{Scf})(template::PWInput, args...) =
    (customizer(args...) ∘ normalizer(Scf(), template))(template)
(::MakeInput{Dfpt})(template::PhInput, previnp::PWInput) =
    normalizer(Dfpt(), previnp)(template)
(::MakeInput{RealSpaceForceConstants})(template::Q2rInput, previnp::PhInput) =
    normalizer(RealSpaceForceConstants(), previnp)(template)
(::MakeInput{T})(
    template::MatdynInput,
    a::Q2rInput,
    b::PhInput,
) where {T<:Union{PhononDispersion,VDos}} = normalizer(T(), (a, b))(template)

struct CalculationSetter <: Setter
    calc::Union{Scf,Dfpt}
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

normalizer(::Scf, args...) = VerbositySetter("high") ∘ CalculationSetter(Scf())
normalizer(::Dfpt, input::PWInput) =
    RelayArgumentsSetter(input) ∘ VerbositySetter("high") ∘ RecoverySetter()
normalizer(::RealSpaceForceConstants, input::PhInput) = RelayArgumentsSetter(input)
normalizer(
    ::PhononDispersion,
    inputs::Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}},
) = RelayArgumentsSetter(inputs) ∘ DosSetter(false)
normalizer(::VDos, inputs::Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}}) =
    RelayArgumentsSetter(inputs) ∘ DosSetter(true)

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    @set! template.control.outdir = abspath(
        joinpath(
            template.control.outdir,
            join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
        ),
    )
    mkpath(template.control.outdir)
    return template
end

customizer(
    ap::AtomicPositionsCard,
    cp::CellParametersCard,
    timefmt::AbstractString = "Y-m-d_H:M:S",
) = OutdirSetter(timefmt) ∘ CellParametersCardSetter(cp) ∘ AtomicPositionsCardSetter(ap)

(x::RunCmd{Scf})(input, output = mktemp(parentdir(input))[1]; kwargs...) =
    pw(input, output; kwargs...)
(x::RunCmd{Dfpt})(input, output = mktemp(parentdir(input))[1]; kwargs...) =
    ph(input, output; kwargs...)
(x::RunCmd{RealSpaceForceConstants})(
    input,
    output = mktemp(parentdir(input))[1];
    kwargs...,
) = q2r(input, output; kwargs...)
(x::RunCmd{<:Union{VDos,PhononDispersion}})(
    input,
    output = mktemp(parentdir(input))[1];
    kwargs...,
) = matdyn(input, output; kwargs...)

getpseudodir(template::PWInput) = abspath(expanduser(template.control.pseudo_dir))

function getpotentials(template::PWInput)
    return map(template.atomic_species.data) do atomic_species
        atomic_species.pseudopot
    end
end
