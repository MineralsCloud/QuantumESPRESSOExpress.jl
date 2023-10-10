using AbInitioSoftwareBase: Setter
using CrystallographyBase: MonkhorstPackGrid
using Dates: format, now
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.PWscf: KMeshCard, PWInput, VerbositySetter
using ExpressBase.Files: parentdir
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: ustrip, @u_str
using UnitfulAtomic

import Express.ConvergenceTestWorkflow: CreateInput
import ExpressBase: RunCmd

(::CreateInput)(template::PWInput, args...) = (customizer(args...) ∘ normalizer())(template)

struct CutoffEnergySetter <: Setter
    wfc::Number
end
function (x::CutoffEnergySetter)(template::PWInput)
    @set! template.system.ecutwfc = ustrip(u"Ry", x.wfc)
    return template
end

struct PseudoDirSetter <: Setter end
function (x::PseudoDirSetter)(template::PWInput)
    @set! template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

normalizer() = VerbositySetter("high") ∘ PseudoDirSetter()

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

struct MonkhorstPackGridSetter <: Setter
    mesh::Vector{Int}
    shift::Vector{Int}
end
function (x::MonkhorstPackGridSetter)(template::PWInput)
    @set! template.k_points = KMeshCard(MonkhorstPackGrid(x.mesh, x.shift))
    return template
end

function customizer(mesh, shift, timefmt="Y-m-d_H:M:S")
    return OutdirSetter(timefmt) ∘ MonkhorstPackGridSetter(mesh, shift)
end
function customizer(energy::Number, timefmt::AbstractString="Y-m-d_H:M:S")
    return OutdirSetter(timefmt) ∘ CutoffEnergySetter(energy)
end

function (x::RunCmd)(input, output=mktemp(parentdir(input))[1]; kwargs...)
    return pw(input, output; kwargs...)
end
