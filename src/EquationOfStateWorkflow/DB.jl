module DB

using ExpressDB: Indexer
using ExpressDB: listfiles, readby
using QuantumESPRESSO.Outputs.PWscf: parse_energy_decomposition

export EosEnergyIndexer, index

struct EosEnergyIndexer <: Indexer end

function index(::EosEnergyIndexer, root_dir=pwd())
    files = listfiles(
        "*/VariableCellOptimization.in" => "*/VariableCellOptimization.out", root_dir
    )
    return readby(files, identity => parse_energy_decomposition)
end

end
