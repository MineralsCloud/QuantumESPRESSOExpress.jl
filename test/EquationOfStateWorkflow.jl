module EquationOfStateWorkflow

using AbInitioSoftwareBase: load
using Crystallography: MonkhorstPackGrid
using EquationsOfStateOfSolids: BirchMurnaghan3rd
using Express.EquationOfStateWorkflow: Scf
using Express.EquationOfStateWorkflow.Config: ExpandConfig
using QuantumESPRESSOExpress.EquationOfStateWorkflow
using QuantumESPRESSO.Inputs.PWscf
using Test
using Unitful: @u_str
using UnitfulAtomic

@testset "Load a configuration file: GaN" begin
    dict = load("../examples/GaN/eos.yaml")
    config = ExpandConfig{Scf}()(dict)
    @test config.template == PWInput(
        control = ControlNamelist(
            pseudo_dir = "/home/qe/pseudo",
            prefix = "GaN",
            outdir = "./tmp",
        ),
        system = SystemNamelist(
            ibrav = 4,
            celldm = [5.95484286816, nothing, 1.63011343669],
            nat = 4,
            ntyp = 2,
            ecutwfc = 160,
        ),
        electrons = ElectronsNamelist(conv_thr = 1e-10),
        atomic_species = AtomicSpeciesCard([
            AtomicSpecies("Ga", 69.723, "Ga.pbe-dn-kjpaw_psl.1.0.0.UPF"),
            AtomicSpecies("N", 14.007, "N.pbe-n-kjpaw_psl.1.0.0.UPF"),
        ]),
        atomic_positions = AtomicPositionsCard(
            [
                AtomicPosition("Ga", [0.666666667, 0.333333333, -0.000051966]),
                AtomicPosition("N", [0.666666667, 0.333333333, 0.376481188]),
                AtomicPosition("Ga", [0.333333333, 0.666666667, 0.499948034]),
                AtomicPosition("N", [0.333333333, 0.666666667, 0.876481188]),
            ],
            "crystal",
        ),
        k_points = KMeshCard(MonkhorstPackGrid([6, 6, 6], [1, 1, 1])),
    )
    @test config.trial_eos ==
          BirchMurnaghan3rd(317.0u"bohr^3", 210u"GPa", 4, -612.43149513u"Ry")
    @test config.fixed == [-5, 0, 5, 10, 15, 20, 25, 30] * u"GPa"
    @test config.save_raw == config.root * "/raw.json"
    @test config.save_eos == config.root * "/eos.jls"
    @test config.save_status == config.root * "/status.jls"
end

@testset "Load a configuration file: Ge" begin
    dict = load("../examples/Ge/eos.yaml")
    config = ExpandConfig{Scf}()(dict)
    @test config.template == PWInput(
        control = ControlNamelist(pseudo_dir = "./pseudo", prefix = "Ge", outdir = "./"),
        system = SystemNamelist(
            ibrav = 2,
            celldm = [7.957636],
            nat = 2,
            ntyp = 1,
            ecutwfc = 55,
        ),
        electrons = ElectronsNamelist(conv_thr = 1e-10),
        atomic_species = AtomicSpeciesCard([
            AtomicSpecies("Ge", 72.64, "Ge.pz-dn-kjpaw_psl.0.2.2.UPF"),
        ]),
        atomic_positions = AtomicPositionsCard(
            [AtomicPosition("Ge", [0, 0, 0]), AtomicPosition("Ge", [0.75, 0.75, 0.75])],
            "crystal",
        ),
        k_points = KMeshCard(MonkhorstPackGrid([6, 6, 6], [1, 1, 1])),
    )
    @test config.trial_eos == BirchMurnaghan3rd(300.44u"bohr^3", 74.88u"GPa", 4.82)
    @test config.fixed == [-5, -2, 0, 5, 10, 15, 17, 20] * u"GPa"
    @test config.save_raw == config.root * "/raw.json"
    @test config.save_eos == config.root * "/eos.jls"
    @test config.save_status == config.root * "/status.jls"
end

end
