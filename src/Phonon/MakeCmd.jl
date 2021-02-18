function (::MakeCmd{Scf})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecOptions(),
    options = PwxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::MakeCmd{Scf})(
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
function (::MakeCmd{Dfpt})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecOptions(),
    options = PhxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::MakeCmd{Dfpt})(
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
function (::MakeCmd{RealSpaceForceConstants})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecOptions(),
    options = Q2rxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::MakeCmd{RealSpaceForceConstants})(
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
function (::MakeCmd{<:Union{VDos,PhononDispersion}})(
    input;
    output = tempname(; cleanup = false),
    error = "",
    mpi = MpiexecOptions(),
    options = MatdynxConfig(),
)
    mkpath(dirname(input))
    @set! options.script_dest = mktemp(dirname(input); cleanup = false)[1]
    return makecmd(input; output = output, error = error, mpi = mpi, options = options)
end
function (x::MakeCmd{<:Union{VDos,PhononDispersion}})(
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

cli(::Type{<:Scf}) = :pw
cli(::Type{<:Dfpt}) = :ph
cli(::Type{<:RealSpaceForceConstants}) = :q2r
cli(::Type{<:Union{PhononDispersion,VDos}}) = :matdyn

function buildjob(x::MakeCmd{T}, cfgfile) where {T}
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
