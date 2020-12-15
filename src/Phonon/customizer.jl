function customize(template::PWInput, new_structure)::PWInput
    @set! template.control.outdir = abspath(mktempdir(
        mkpath(template.control.outdir);
        prefix = template.control.prefix * format(now(), "_Y-m-d_H:M:S_"),
        cleanup = false,
    ))
    template = set_cell(template, new_structure...)
    template = set_verbosity(template, "high")
    return template
end
customize(template::PWInput) = template
customize(template::PhInput, pw::PWInput)::PhInput = relayinfo(pw, template)
customize(template::Q2rInput, ph::PhInput)::Q2rInput = relayinfo(ph, template)
customize(template::MatdynInput, q2r::Q2rInput, ph::PhInput)::MatdynInput =
    relayinfo(q2r, relayinfo(ph, template))
customize(template::MatdynInput, ph::PhInput, q2r::Q2rInput) = customize(template, q2r, ph)
