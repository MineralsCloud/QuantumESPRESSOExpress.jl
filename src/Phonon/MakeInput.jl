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

struct CalculationSetter{T<:Union{Scf,Dfpt}} <: Setter
    calc::T
end
function (::CalculationSetter{Scf})(template::PWInput)
    @set! template.control.calculation = "scf"
    return template
end

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
    customize = OutdirSetter(x.timefmt) ∘ StructureSetter(x.cp, x.ap)
    return customize(template)
end
