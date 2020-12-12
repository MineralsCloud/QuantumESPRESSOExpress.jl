struct OutdirSetter{T} <: Setter
    timefmt::T
end
OutdirSetter() = OutdirSetter("Y-m-d_H:M:S")
function (x::OutdirSetter)(template::PWInput)
    @set! template.control.outdir = abspath(joinpath(
        template.control.outdir,
        template.control.prefix * format(now(), x.timefmt),
    ))
    return template
end

customize(a, b) = customize(b, a)  # If no method found, switch arguments & try again
function customize(pressure::Pressure, volume::Volume)
    function _customize(template::PWInput)::PWInput
        set = OutdirSetter() ∘ VolumeSetter(volume) ∘ PressureSetter(pressure)
        return set(template)
    end
end
function customize(pressure::Pressure, eos::PressureEOS)
    function _customize(template::PWInput)::PWInput
        volume = mustfindvolume(eos, pressure; volume_scale = (0.5, 1.5))
        set = OutdirSetter() ∘ VolumeSetter(volume) ∘ PressureSetter(pressure)
        return set(template)
    end
end
customize(pressure::Pressure, eos::EquationOfStateOfSolids) =
    customize(pressure, PressureEOS(getparam(eos)))
