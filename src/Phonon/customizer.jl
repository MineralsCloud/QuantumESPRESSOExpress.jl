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
    cp::A
    ap::B
    timefmt::String
end
function (x::Customizer)(template::PWInput)::PWInput
    customize = OutdirSetter(x.timefmt) ∘ StructureSetter(x.cp, x.ap)
    return customize(template)
end
