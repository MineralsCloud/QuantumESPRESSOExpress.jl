module DefaultActions

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
using QuantumESPRESSO.Commands: PwxConfig, PhxConfig, Q2rxConfig, MatdynxConfig, makecmd
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

normalizer(calc::Scf) =VerbositySetter("high") ∘ CalculationSetter(Scf())
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

function (::RunCmd{Scf})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecConfig(),
    options = PwxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::RunCmd{Scf})(
    inputs::AbstractArray;
    outputs,
    errors = outputs,
    mpi,
    options = PwxConfig(),
)
    if !isempty(outputs)
        if size(inputs) != size(outputs)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    if !isempty(errors)
        if size(inputs) != size(errors)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    @set! mpi.np = distprocs(mpi.np, length(inputs))
    distkeys = []
    for (key, value) in mpi.options
        if value isa AbstractArray
            push!(distkeys, key)
        end
    end
    return map(enumerate(inputs)) do (i, input)
        tempmpi = mpi
        for key in distkeys
            @set! tempmpi.options[key] = mpi.options[key][i]
        end
        x(input; output = outputs[i], error = errors[i], mpi = tempmpi, options = options)
    end
end
function (::RunCmd{Dfpt})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecConfig(),
    options = PhxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::RunCmd{Dfpt})(
    inputs::AbstractArray;
    outputs,
    errors = outputs,
    mpi,
    options = PhxConfig(),
)
    if !isempty(outputs)
        if size(inputs) != size(outputs)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    if !isempty(errors)
        if size(inputs) != size(errors)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    @set! mpi.np = distprocs(mpi.np, length(inputs))
    distkeys = []
    for (key, value) in mpi.options
        if value isa AbstractArray
            push!(distkeys, key)
        end
    end
    return map(enumerate(inputs)) do (i, input)
        tempmpi = mpi
        for key in distkeys
            @set! tempmpi.options[key] = mpi.options[key][i]
        end
        x(input; output = outputs[i], error = errors[i], mpi = tempmpi, options = options)
    end
end
function (::RunCmd{RealSpaceForceConstants})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecConfig(),
    options = Q2rxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::RunCmd{RealSpaceForceConstants})(
    inputs::AbstractArray;
    outputs,
    errors = outputs,
    mpi,
    options = Q2rxConfig(),
)
    if !isempty(outputs)
        if size(inputs) != size(outputs)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    if !isempty(errors)
        if size(inputs) != size(errors)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    @set! mpi.np = distprocs(mpi.np, length(inputs))
    distkeys = []
    for (key, value) in mpi.options
        if value isa AbstractArray
            push!(distkeys, key)
        end
    end
    return map(enumerate(inputs)) do (i, input)
        tempmpi = mpi
        for key in distkeys
            @set! tempmpi.options[key] = mpi.options[key][i]
        end
        x(input; output = outputs[i], error = errors[i], mpi = tempmpi, options = options)
    end
end
function (::RunCmd{<:Union{VDos,PhononDispersion}})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecConfig(),
    options = MatdynxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::RunCmd{<:Union{VDos,PhononDispersion}})(
    inputs::AbstractArray;
    outputs,
    errors = outputs,
    mpi,
    options = MatdynxConfig(),
)
    if !isempty(outputs)
        if size(inputs) != size(outputs)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    if !isempty(errors)
        if size(inputs) != size(errors)
            throw(DimensionMismatch("size of inputs and outputs are different!"))
        end
    end
    @set! mpi.np = distprocs(mpi.np, length(inputs))
    distkeys = []
    for (key, value) in mpi.options
        if value isa AbstractArray
            push!(distkeys, key)
        end
    end
    return map(enumerate(inputs)) do (i, input)
        tempmpi = mpi
        for key in distkeys
            @set! tempmpi.options[key] = mpi.options[key][i]
        end
        x(input; output = outputs[i], error = errors[i], mpi = tempmpi, options = options)
    end
end

function buildjob(x::RunCmd{T}, cfgfile) where {T}
    config = loadconfig(cfgfile)
    infiles = map(dir -> joinpath(dir, shortname(T) * ".in"), config.dirs)
    outfiles = map(dir -> joinpath(dir, shortname(T) * ".out"), config.dirs)
    jobs = map(
        ExternalAtomicJob,
        x(
            infiles;
            outputs = outfiles,
            mpi = config.cli.mpi,
            options = getproperty(config.cli, cli(T)),
        ),
    )
    return parallel(jobs...)
end

end
