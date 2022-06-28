from hsms.streamables import Program

from typing import List

from hsms.puzzles.load_clvm import load_clvm
from hsms.streamables import Program


CAV_MOD = load_clvm(
    "composite_amount_validation.cl", package_or_requirement="clvm_contracts"
)


def layer_puzzle() -> Program:
    return Program.to((CAV_MOD, Program.to(0)))


def solution_for_layer(
    index_of_condition: int, amount_factor_1: int, amount_factor_2: int
) -> Program:
    return Program.to([index_of_condition, amount_factor_1, amount_factor_2])
