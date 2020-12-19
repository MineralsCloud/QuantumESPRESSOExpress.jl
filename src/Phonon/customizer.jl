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

struct Customizer{T<:Scf,A,B}
    cp::A
    ap::B
    timefmt::String
end
function (x::Customizer{Scf})(template::PWInput)
    customize = OutdirSetter(x.timefmt) ∘ StructureSetter(x.cp, x.ap)
    template = customize(template)
end
function (x::Customizer{Dfpt})(template::PhInput)
    relayinfo(pw, template)
    template = customize(template)
end
function (x::Customizer{RealSpaceForceConstants})(template::Q2rInput)
    relayinfo(ph, template)
    template = customize(template)
end
function (x::Customizer{<:Union{PhononDispersion,VDos}})(template::MatdynInput)
    relayinfo(q2r, relayinfo(ph, template))
    template = customize(template)
end
