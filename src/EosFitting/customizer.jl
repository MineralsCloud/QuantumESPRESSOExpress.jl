struct OutdirSetter <: Setter
    timefmt::String
end
function (x::OutdirSetter)(template::PWInput)
    @set! template.control.outdir = abspath(joinpath(
        template.control.outdir,
        join((template.control.prefix, format(now(), x.timefmt), rand(UInt)), '_'),
    ))
    return template
end

struct Customizer{A,B}
    a::A
    b::B
    vscale::NTuple{2,Float64}
end
Customizer(a, b) = Customizer(a, b, (0.5, 1.5))
function (x::Customizer{<:Pressure,<:Volume})(template::PWInput)::PWInput
    customize = OutdirSetter() ∘ VolumeSetter(x.b) ∘ PressureSetter(x.a)
    return customize(template)
end
function (x::Customizer{<:Pressure,<:EquationOfStateOfSolids})(template::PWInput)
    volume = mustfindvolume(x.b, x.a; vscale = x.vscale)
    x = @set! x.b = volume
    return x(template)
end
function (x::Customizer{<:Pressure,<:Parameters})(template::PWInput)
    x = @set! x.b = PressureEOS(x.b)
    return x(template)
end
(x::Customizer)(template::PWInput) = Customizer(x.b, x.a, x.vscale)(template)  # If no method found, switch arguments & try again
