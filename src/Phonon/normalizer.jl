# This is a helper function and should not be exported.
standardize(template::PWInput, ::SelfConsistentField)::PWInput =
    @set(template.control.calculation = "scf")
standardize(template::PhInput, ::Dfpt)::PhInput = @set(template.inputph.verbosity = "high")
standardize(template::Q2rInput, ::RealSpaceForceConstants)::Q2rInput = template
standardize(template::MatdynInput, ::PhononDispersion)::MatdynInput =
    @set(template.input.dos = false)
standardize(template::MatdynInput, ::VDos)::MatdynInput = @set(template.input.dos = true)
