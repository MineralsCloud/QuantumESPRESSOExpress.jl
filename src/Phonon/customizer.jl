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
    timefmt::String
end

function (::Customizer)(template::PWInput, new_structure)::PWInput
    customize = OutdirSetter(x.timefmt) ∘ VolumeSetter(x.b) ∘ PressureSetter(x.a)
    template = set_cell(template, new_structure...)
end
customize(template::PhInput, pw::PWInput)::PhInput = relayinfo(pw, template)
customize(template::Q2rInput, ph::PhInput)::Q2rInput = relayinfo(ph, template)
customize(template::MatdynInput, q2r::Q2rInput, ph::PhInput)::MatdynInput =
    relayinfo(q2r, relayinfo(ph, template))
customize(template::MatdynInput, ph::PhInput, q2r::Q2rInput) = customize(template, q2r, ph)
