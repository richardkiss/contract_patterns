from typing import List, Tuple

from hsms.atoms import bytes32
from hsms.puzzles.load_clvm import load_clvm
from hsms.streamables import Program

VMP_MOD = load_clvm(
    "validating_meta_puzzle.cl", package_or_requirement="clvm_contracts"
)


def puzzle_for_layers(list_of_layers: List[Program]) -> Program:
    return VMP_MOD.curry(list_of_layers)


def puzzle_hash_for_layer_hashes(
    list_of_layers: List[Tuple[bytes32, bytes32]]
) -> bytes32:
    pass


def create_solution(*layer_solutions: Tuple[Program]) -> Program:
    return Program.to(list(layer_solutions))
