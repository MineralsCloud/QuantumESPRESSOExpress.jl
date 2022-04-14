using AbInitioSoftwareBase: parentdir
using AbInitioSoftwareBase.Inputs: Setter
using Crystallography: MonkhorstPackGrid
using Dates: format, now
using QuantumESPRESSO.Commands: pw
using QuantumESPRESSO.Inputs.PWscf: KMeshCard, PWInput, VerbositySetter
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: ustrip, @u_str
using UnitfulAtomic

import Express.ConvergenceTestWorkflow: MakeInput, RunCmd

(::MakeInput)(template::PWInput, args...) = (customizer(args...) ∘ normalizer())(template)

struct CutoffEnergySetter <: Setter
    wfc::Number
end
function (x::CutoffEnergySetter)(template::PWInput)
    @set! template.system.ecutwfc = ustrip(u"Ry", x.wfc)
    return template
end

struct PseudodirSetter <: Setter end
function (x::PseudodirSetter)(template::PWInput)
    @set! template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

normalizer() = VerbositySetter("high") ∘ PseudodirSetter()

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    # If an absolute path is given, then do nothing; else,
    # set `outdir` to the current directory + `outdir` + a subdirectory.
    @set! template.control.outdir = if !isabspath(template.control.outdir)
        abspath(
            joinpath(
                template.control.outdir,
                join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
            ),
        )
    end
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

customizer(mesh, shift, timefmt = "Y-m-d_H:M:S") =
    OutdirSetter(timefmt) ∘ MonkhorstPackGridSetter(mesh, shift)
customizer(energy::Number, timefmt::AbstractString = "Y-m-d_H:M:S") =
    OutdirSetter(timefmt) ∘ CutoffEnergySetter(energy)

(x::RunCmd)(input, output = mktemp(parentdir(input))[1]; kwargs...) =
    pw(input, output; kwargs...)
