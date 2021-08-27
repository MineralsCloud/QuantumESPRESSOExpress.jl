module DefaultActions

using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Inputs: Setter
using AbInitioSoftwareBase.Commands: MpiexecConfig
using Dates: format, now
using Express: Calculation, Scf
using Express.EquationOfStateWorkflow: VcOptim
using Express.PhononWorkflow: Dfpt, RealSpaceForceConstants, PhononDispersion, VDos
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

import Express.PhononWorkflow.DefaultActions:
    MakeInput, RunCmd, parsecell, inputtype, buildjob
import Express.Shell: distprocs

inputtype(x::Calculation) = inputtype(typeof(x))
inputtype(::Type{Scf}) = PWInput
inputtype(::Type{Dfpt}) = PhInput
inputtype(::Type{RealSpaceForceConstants}) = Q2rInput
inputtype(::Type{<:Union{PhononDispersion,VDos}}) = MatdynInput

parsecell(str) =
    tryparsefinal(CellParametersCard, str), tryparsefinal(AtomicPositionsCard, str)

(::MakeInput{T})(template::PWInput, args...) where {T<:Scf} =
    (Customizer(args...) ∘ Normalizer(T(), template))(template)
(::MakeInput{T})(template::PhInput, previnp::PWInput) where {T<:Dfpt} =
    Normalizer(T(), previnp)(template)
(::MakeInput{T})(template::Q2rInput, previnp::PhInput) where {T<:RealSpaceForceConstants} =
    Normalizer(T(), previnp)(template)
(::MakeInput{T})(template::Q2rInput, previnp::PhInput) where {T<:RealSpaceForceConstants} =
    Normalizer(T(), previnp)(template)
(::MakeInput{T})(
    template::MatdynInput,
    a::Q2rInput,
    b::PhInput,
) where {T<:Union{PhononDispersion,VDos}} = Normalizer(T(), (a, b))(template)
(x::MakeInput{T})(
    template::MatdynInput,
    a::Q2rInput,
    b::PhInput,
) where {T<:Union{PhononDispersion,VDos}} = x(template, b, a)

struct CalculationSetter <: Setter
    calc::Union{Scf,Dfpt}
end
function (::CalculationSetter)(template::PWInput)
    @set! template.control.calculation = "scf"
    return template
end

normalizer(calc::Scf) = VerbositySetter("high") ∘ CalculationSetter(Scf())
normalizer(calc::Dfpt) = 1
struct Normalizer{T,S}
    calc::T
    args::S
end
function (x::Normalizer{Scf})(template::PWInput)::PWInput
    normalize = VerbositySetter("high") ∘ CalculationSetter(Scf())
    return normalize(template)
end
function (x::Normalizer{Dfpt,PWInput})(template::PhInput)::PhInput
    normalize = Base.Fix1(relayinfo, x.args) ∘ VerbositySetter("high")
    return normalize(template)
end
(x::Normalizer{RealSpaceForceConstants,PhInput})(template::Q2rInput)::Q2rInput =
    relayinfo(x.args, template)
function (
    x::Normalizer{
        PhononDispersion,
        <:Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}},
    }
)(
    template::MatdynInput,
)::MatdynInput
    @set! template.input.dos = false
    normalize = Base.Fix1(relayinfo, x.args[2]) ∘ Base.Fix1(relayinfo, x.args[1])
    return normalize(template)
end
function (x::Normalizer{VDos,<:Union{Tuple{Q2rInput,PhInput},Tuple{PhInput,Q2rInput}}})(
    template::MatdynInput,
)::MatdynInput
    @set! template.input.dos = true
    normalize = Base.Fix1(relayinfo, x.args[2]) ∘ Base.Fix1(relayinfo, x.args[1])
    return normalize(template)
end

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

struct Customizer
    cp::CellParametersCard
    ap::AtomicPositionsCard
    timefmt::String
end
Customizer(a, b) = Customizer(a, b, "Y-m-d_H:M:S")
function (x::Customizer)(template::PWInput)::PWInput
    customize =
        OutdirSetter(x.timefmt) ∘ CellParametersCardSetter(x.cp) ∘
        AtomicPositionsCardSetter(x.ap)
    return customize(template)
end

(x::RunCmd{Scf})(input, output = mktemp(parentdir(input))[1], error = output; kwargs...) =
    pw(input, output, error; kwargs...)
(x::RunCmd{Dfpt})(input, output = mktemp(parentdir(input))[1], error = output; kwargs...) =
    ph(input, output, error; kwargs...)
(x::RunCmd{RealSpaceForceConstants})(
    input,
    output = mktemp(parentdir(input))[1],
    error = output;
    kwargs...,
) = q2r(input, output, error; kwargs...)
(x::RunCmd{<:Union{VDos,PhononDispersion}})(
    input,
    output = mktemp(parentdir(input))[1],
    error = output;
    kwargs...,
) = matdyn(input, output, error; kwargs...)

end
