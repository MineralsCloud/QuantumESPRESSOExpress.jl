using AbInitioSoftwareBase: Setter
using CrystallographyBase: MonkhorstPackGrid
using Dates: format, now
using ExpressBase.Files: parentdir
using QuantumESPRESSO.PWscf:
    PWInput, KMeshCard, PWInput, VerbositySetter, parse_electrons_energies
using Setfield: @set!
using UnifiedPseudopotentialFormat  # To work with `download_potential`
using Unitful: ustrip, @u_str
using UnitfulAtomic

import Express.ConvergenceTestWorkflow: CreateInput, ExtractData
import ExpressBase: RunCmd

struct DataExtractionFailed <: Exception
    msg::String
end

function (::ExtractData)(file)
    str = read(file, String)
    preamble = tryparse(Preamble, str)
    e = try
        parse_electrons_energies(str, :converged)
    catch
    end
    if preamble !== nothing && !isempty(e)
        return preamble.ecutwfc * u"Ry" => e.ε[end] * u"Ry"  # volume, energy
    else
        throw(DataExtractionFailed("no data found in file $file."))
    end
end

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

customizer(mesh, shift) = OutdirSetter("Y-m-d_H:M:S") ∘ MonkhorstPackGridSetter(mesh, shift)
customizer(energy::Number) = OutdirSetter("Y-m-d_H:M:S") ∘ CutoffEnergySetter(energy)

function (x::RunCmd)(input, output=mktemp(parentdir(input))[1]; kwargs...)
    return pw(input, output; kwargs...)
end
