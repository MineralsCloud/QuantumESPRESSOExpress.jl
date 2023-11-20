using AbInitioSoftwareBase: Setter
using CrystallographyBase: MonkhorstPackGrid
using Dates: format, now
using QuantumESPRESSO.PWscf:
    PWInput, KMeshCard, PWInput, VerbositySetter, Preamble, eachconvergedenergy
using Accessors: @reset
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: ustrip, @u_str
using UnitfulAtomic

import Express.ConvergenceTest: CreateInput, ExtractData

struct DataExtractionFailed <: Exception
    msg::String
end

function (::ExtractData)(file)
    str = read(file, String)
    preamble = tryparse(Preamble, str)
    energies = collect(eachconvergedenergy(str))
    if !isnothing(preamble) && !isempty(energies)
        return preamble.ecutwfc * u"Ry" => last(energies).total * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end

(::CreateInput)(template::PWInput, args...) = (customizer(args...) ∘ normalizer())(template)

struct CutoffEnergySetter <: Setter
    wfc::Number
end
function (x::CutoffEnergySetter)(template::PWInput)
    @reset template.system.ecutwfc = ustrip(u"Ry", x.wfc)
    return template
end

struct PseudoDirSetter <: Setter end
function (x::PseudoDirSetter)(template::PWInput)
    @reset template.control.pseudo_dir = abspath(template.control.pseudo_dir)
    return template
end

normalizer() = VerbositySetter("high") ∘ PseudoDirSetter()

struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    # Set `outdir` to `outdir` + a subdirectory.
    @reset template.control.outdir = abspath(
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
    @reset template.k_points = KMeshCard(MonkhorstPackGrid(x.mesh, x.shift))
    return template
end

customizer(mesh, shift) = OutdirSetter("Y-m-d_H:M:S") ∘ MonkhorstPackGridSetter(mesh, shift)
customizer(energy::Number) = OutdirSetter("Y-m-d_H:M:S") ∘ CutoffEnergySetter(energy)
