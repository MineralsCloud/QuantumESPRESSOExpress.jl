module PhononWorkflow

using AbInitioSoftwareBase: load
using Express.PhononWorkflow: Scf, Dfpt
using Express.PhononWorkflow.Config: ExpandConfig
using QuantumESPRESSOExpress.PhononWorkflow
using QuantumESPRESSO.Inputs.PHonon:
    PhNamelist, Q2rNamelist, MatdynNamelist, PhInput, Q2rInput, MatdynInput
using Test
using Unitful: @u_str
using UnitfulAtomic

@testset "Load a configuration file: Ge" begin
    dict = load("../examples/Ge/phonon.yaml")
    config = ExpandConfig{Scf}()(dict)
    @test config.template.dfpt == PhInput(
        "Phonon",
        PhNamelist(;
            verbosity = "high",
            fildyn = "dyn",
            outdir = "./tmp",
            prefix = "Ge",
            ldisp = true,
            tr2_ph = 1e-14,
            nq1 = 2,
            nq2 = 2,
            nq3 = 2,
            amass = [72.64],
        ),
        nothing,
    )
    @test config.template.q2r ==
          Q2rInput(Q2rNamelist(; fildyn = "dyn", zasr = "crystal", flfrc = "fc.out"))
    @test config.template.disp == MatdynInput(
        MatdynNamelist(;
            asr = "crystal",
            amass = [72.64],
            flfrc = "fc.out",
            flfrq = "freq.out",
            flvec = "modes.out",
            dos = true,
            q_in_band_form = false,
            nk1 = 8,
            nk2 = 8,
            nk3 = 8,
        ),
    )
    @test config.fixed == [-5, -2, 0, 5, 10, 15, 17, 20] * u"GPa"
    if !Sys.iswindows()
        @test config.save_raw == config.root * "/raw.json"
        @test config.save_status == config.root * "/status.jld2"
    end
end

end
