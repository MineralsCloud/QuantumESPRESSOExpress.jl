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
    return template
end

struct Customizer{A,B}
    a::A
    b::B
    timefmt::String
end
Customizer(a, b) = Customizer(a, b, "Y-m-d_H:M:S")
function (x::Customizer{<:Pressure,<:Volume})(template::PWInput)::PWInput
    customize = OutdirSetter(x.timefmt) ∘ VolumeSetter(x.b) ∘ PressureSetter(x.a)
    return customize(template)
end
function (x::Customizer{<:Pressure,<:EquationOfStateOfSolids})(template::PWInput)
    volume = mustfindvolume(x.b, x.a; vscale = vscale())
    x = @set! x.b = volume
    return x(template)
end
function (x::Customizer{<:Pressure,<:Parameters})(template::PWInput)
    x = @set! x.b = PressureEos(x.b)
    return x(template)
end
(x::Customizer)(template::PWInput) = Customizer(x.b, x.a, x.timefmt)(template)  # If no method found, switch arguments & try again
