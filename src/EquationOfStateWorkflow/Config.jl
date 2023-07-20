module Config

using Configurations: OptionField, @option
using ExpressBase.Config: SoftwareConfig
using QuantumESPRESSO.PWscf: PWInput

import Configurations: from_dict
import Express.EquationOfStateWorkflow.Config: StaticConfig, _update!

function _update!(conf, template::AbstractString)
    str = read(expanduser(template), String)
    conf.template = parse(PWInput, str)
    return conf
end

@option struct MpiexecOptions <: SoftwareConfig
    path::String = "mpiexec"
    f::String = ""
    hosts::Vector{String} = String[]
    wdir::String = ""
    configfile::String = ""
    env::Union{Dict,Vector} = Dict(ENV)
    np::UInt = 1
end

const MpiexecConfig = MpiexecOptions

"""
    ParallelizationFlags(; nimage=0, npool=0, ntg=0, nyfft=0, nband=0, ndiag=0)

Construct parallelization flags of QuantumESPRESSO commands.
"""
@option mutable struct ParallelizationFlags
    nimage::UInt = 0
    npool::UInt = 0
    ntg::UInt = 0
    nyfft::UInt = 0
    nband::UInt = 0
    ndiag::UInt = 0
end

"""
    PwxConfig(; path, chdir, options)

Create configurations for `pw.x`.

# Arguments
- `path::String="pw.x"`: the path to the executable.
- `chdir::Bool=true`: whether to change directory to where the input file is
  stored when running `pw.x`. If `false`, stay in the current directory.
- `options::ParallelizationFlags=ParallelizationFlags()`: the parallelization
  flags of `pw.x`.
"""
@option mutable struct PwxConfig <: SoftwareConfig
    path::String = "pw.x"
    chdir::Bool = true
    options::ParallelizationFlags = ParallelizationFlags()
    env::Union{Dict,Vector} = Dict(ENV)
end
"""
    PhxConfig(; path, chdir, options)

Create configurations for `ph.x`.

# Arguments
- `path::String="ph.x"`: the path to the executable.
- `chdir::Bool=true`: whether to change directory to where the input file is
  stored when running `ph.x`. If `false`, stay in the current directory.
- `options::ParallelizationFlags=ParallelizationFlags()`: the parallelization
  flags of `ph.x`.
"""
@option mutable struct PhxConfig <: SoftwareConfig
    path::String = "ph.x"
    chdir::Bool = true
    options::ParallelizationFlags = ParallelizationFlags()
    env::Union{Dict,Vector} = Dict(ENV)
end
"""
    Q2rxConfig(; path, chdir, options)

Create configurations for `q2r.x`.

# Arguments
- `path::String="q2r.x"`: the path to the executable.
- `chdir::Bool=true`: whether to change directory to where the input file is
  stored when running `q2r.x`. If `false`, stay in the current directory.
- `options::ParallelizationFlags=ParallelizationFlags()`: the parallelization
  flags of `q2r.x`.
"""
@option mutable struct Q2rxConfig <: SoftwareConfig
    path::String = "q2r.x"
    chdir::Bool = true
    options::ParallelizationFlags = ParallelizationFlags()
    env::Union{Dict,Vector} = Dict(ENV)
end
"""
    MatdynxConfig(; path, chdir, options)

Create configurations for `matdyn.x`.

# Arguments
- `path::String="matdyn.x"`: the path to the executable.
- `chdir::Bool=true`: whether to change directory to where the input file is
  stored when running `matdyn.x`. If `false`, stay in the current directory.
- `options::ParallelizationFlags=ParallelizationFlags()`: the parallelization
  flags of `matdyn.x`.
"""
@option mutable struct MatdynxConfig <: SoftwareConfig
    path::String = "matdyn.x"
    chdir::Bool = true
    options::ParallelizationFlags = ParallelizationFlags()
    env::Union{Dict,Vector} = Dict(ENV)
end
"""
    DynmatxConfig(; path, chdir, options)

Create configurations for `dynmat.x`.

# Arguments
- `path::String="dynmat.x"`: the path to the executable.
- `chdir::Bool=true`: whether to change directory to where the input file is
  stored when running `dynmat.x`. If `false`, stay in the current directory.
- `options::ParallelizationFlags=ParallelizationFlags()`: the parallelization
  flags of `dynmat.x`.
"""
@option mutable struct DynmatxConfig <: SoftwareConfig
    path::String = "dynmat.x"
    chdir::Bool = true
    options::ParallelizationFlags = ParallelizationFlags()
    env::Union{Dict,Vector} = Dict(ENV)
end

@option mutable struct QuantumESPRESSOConfig <: SoftwareConfig
    mpi::MpiexecConfig = MpiexecConfig()
    pw::PwxConfig = PwxConfig()
    ph::PhxConfig = PhxConfig()
    q2r::Q2rxConfig = Q2rxConfig()
    matdyn::MatdynxConfig = MatdynxConfig()
    dynmat::DynmatxConfig = DynmatxConfig()
end

function from_dict(
    ::Type{<:StaticConfig}, ::OptionField{:cli}, ::Type{SoftwareConfig}, dict
)
    return QuantumESPRESSOConfig(;
        mpi=get(dict, "mpi", MpiexecConfig()), pw=get(dict, "pw", PwxConfig())
    )
end

end
