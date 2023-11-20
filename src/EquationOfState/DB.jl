module DB

using ExpressDB: Indexer
using ExpressDB: listfiles, readby
using QuantumESPRESSO.PWscf: parse_electrons_energies, parse_smearing_energy

export EosEnergyIndexer, index

struct EosEnergyIndexer{T} <: Indexer
    parser::T
end

function index(indexer::EosEnergyIndexer, root_dir=pwd())
    files = listfiles(
        "*/VariableCellOptimization.in" => "*/VariableCellOptimization.out", root_dir
    )
    return readby(files, identity => indexer.parser)
end

end
