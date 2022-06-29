from hsms.streamables import Program

from typing import List

from hsms.atoms import bytes32
from hsms.puzzles.load_clvm import load_clvm
from hsms.streamables import Program

from .validating_meta_puzzle import VMP_MOD


RLV_MOD = load_clvm("rate_limit_validation.cl", package_or_requirement="clvm_contracts")


def layer_puzzle(
    seconds_per_interval: int, mojos_per_interval: int, zero_date: int
) -> Program:
    return Program.to(
        (
            RLV_MOD,
            Program.to(
                [
                    [
                        VMP_MOD.tree_hash(),
                        RLV_MOD.tree_hash(),
                        seconds_per_interval,
                        mojos_per_interval,
                        zero_date,
                    ]
                ]
            ),
        )
    )


def solution_for_layer(
    seconds_per_interval: int,
    mojos_per_interval: int,
    zero_date: int,
    now: int,
    assert_later_condition_index: int,
    change_condition_index: int,
    change_validating_puzzle_index: int,
    validating_puzzles_list: List[bytes32],
) -> Program:
    interval_count = max(
        0, (zero_date - now + seconds_per_interval - 1) // seconds_per_interval
    )
    return Program.to(
        [
            now,
            interval_count,
            assert_later_condition_index,
            change_condition_index,
            change_validating_puzzle_index,
            validating_puzzles_list,
        ]
    )
