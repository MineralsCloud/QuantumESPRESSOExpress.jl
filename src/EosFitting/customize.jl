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

struct Customizer{A,B}
    a::A
    b::B
end
function (x::Customizer{<:Pressure,<:Volume})(template::PWInput)::PWInput
    customize = OutdirSetter() ∘ VolumeSetter(x.b) ∘ PressureSetter(x.a)
    return customize(template)
end
function (x::Customizer{<:Pressure,<:PressureEOS})(template::PWInput)
    volume = mustfindvolume(x.b, x.a; volume_scale = (0.5, 1.5))
    return Customizer(x.a, volume)(template)
end
(x::Customizer{<:Pressure,<:EquationOfStateOfSolids})(template::PWInput) =
    Customizer(x.a, PressureEOS(getparam(x.b)))(template)
(x::Customizer)(template::PWInput) = Customizer(x.b, x.a)(template)  # If no method found, switch arguments & try again
