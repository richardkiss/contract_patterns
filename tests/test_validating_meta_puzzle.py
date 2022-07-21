import math

from unittest import TestCase

from clvm.EvalError import EvalError

from hsms.atoms import bytes32
from hsms.bls12_381.BLSSecretExponent import BLSSecretExponent
from hsms.puzzles.load_clvm import load_clvm

from hsms.puzzles.p2_delegated_puzzle_or_hidden_puzzle import (
    solution_for_conditions,
    MOD as P2DPOHP_MOD,
)
from hsms.streamables import Program

from clvm_contracts import (
    composite_amount_validation,
    rate_limit_validation,
    validating_meta_puzzle,
)

ALLOW_EVERYTHING_MOD = load_clvm(
    "allow_everything.cl", package_or_requirement="clvm_contracts"
)

ANYONE_CAN_SPEND_PUZZLE = Program.to(1)


def create_inner_puzzle_layer():
    secret_exponent = BLSSecretExponent.from_int(1)
    public_key = secret_exponent.public_key()
    inner_layer = (P2DPOHP_MOD, [bytes(public_key)])
    return inner_layer


def dump_brun(prog: Program, args: Program):
    """
    Display info on how to debug from the shell
    """
    print(
        "\n***\nbrun -y main.sym -x %s %s\n***\n" % (Program.to(prog), Program.to(args))
    )


def drun(prog: Program, args: Program) -> Program:
    """
    "debug run" - run the program and dump out debug `brun` text if it fails
    """
    try:
        return Program.to(prog).run(Program.to(args))
    except EvalError as ex:
        # print(repr(ex))
        # print(repr(ex._sexp))
        dump_brun(prog, args)
        raise


def run_validator(
    prog: Program, args: Program, expected_rv: int = 1, expected_raise: bool = False
) -> Program:
    """
    Test a validating layer. If an unexpected thing happens (raises when it shouldn't or
    doesn't raise when it should; or returns the wrong value) dump out the `brun` syntax
    to facilitate debugging.
    """
    try:
        r = Program.to(prog).run(Program.to(args))
        if r.as_int() != expected_rv:
            dump_brun(prog, args)
        assert r.as_int() == expected_rv
    except EvalError as ex:
        if not expected_raise:
            dump_brun(prog, args)
        return ex._sexp
    if expected_raise:
        raise RuntimeError("expected raise")
    return r


class Tests(TestCase):
    def test_just_inner(self):
        inner_layer = create_inner_puzzle_layer()
        all_layers = [inner_layer]
        contract = validating_meta_puzzle.puzzle_for_layers(all_layers)
        b32 = bytes32([0] * 32)
        inner_solution = solution_for_conditions([[51, b32, 1000]])
        solution = validating_meta_puzzle.create_solution([inner_solution])
        output = drun(contract, solution)

    def test_just_composite_layer(self):
        composite_layer = composite_amount_validation.layer_puzzle()
        composite_puzzle = composite_layer.at("f")
        b32 = bytes32([0] * 32)
        conditions = Program.to([[51, b32, 1000], [51, b32, 1001], [1, "junk", 1001]])

        # success case
        composite_solution = composite_amount_validation.solution_for_layer(0, 20, 50)
        args = Program.to((conditions, composite_solution))
        r = run_validator(composite_puzzle, args)

        # failed due to non-proof (one factor is 1)
        composite_solution = composite_amount_validation.solution_for_layer(0, 1, 1000)
        args = Program.to((conditions, composite_solution))
        r = run_validator(composite_puzzle, args, expected_rv=0)

        # failed due to bad proof
        composite_solution = composite_amount_validation.solution_for_layer(0, 21, 50)
        args = Program.to((conditions, composite_solution))
        r = run_validator(composite_puzzle, args, expected_rv=0)

        # success for 1001
        composite_solution = composite_amount_validation.solution_for_layer(1, 11, 91)
        args = Program.to((conditions, composite_solution))
        r = run_validator(composite_puzzle, args)

        # failed due to indexed condition not `CREATE_COIN`
        composite_solution = composite_amount_validation.solution_for_layer(2, 11, 91)
        args = Program.to((conditions, composite_solution))
        r = run_validator(composite_puzzle, args, expected_raise=True)

    def test_allow_everything_and_inner_layers(self):
        inner_layer = create_inner_puzzle_layer()
        composite_layer = composite_amount_validation.layer_puzzle()
        all_layers = [(ALLOW_EVERYTHING_MOD, 0), inner_layer]
        contract = validating_meta_puzzle.puzzle_for_layers(all_layers)
        b32 = bytes32([0] * 32)
        inner_solution = solution_for_conditions([[51, b32, 1000]])
        allow_everything_solution = ["obj0", "obj1", "obj2"]
        solution = validating_meta_puzzle.create_solution(
            [allow_everything_solution, inner_solution]
        )
        output = drun(contract, solution)

    def test_composite_and_inner_layers(self):
        inner_layer = create_inner_puzzle_layer()
        composite_layer = composite_amount_validation.layer_puzzle()
        all_layers = [composite_layer, inner_layer]
        contract = validating_meta_puzzle.puzzle_for_layers(all_layers)
        b32 = bytes32([0] * 32)
        conditions = [[51, b32, 1000]]
        inner_solution = solution_for_conditions(conditions)
        composite_solution = composite_amount_validation.solution_for_layer(1, 20, 50)
        solution = validating_meta_puzzle.create_solution(
            [composite_solution, inner_solution]
        )
        output = drun(contract, solution)
        aggsig_condition = [
            50,
            inner_layer[1][0],
            Program.to((1, conditions)).tree_hash(),
        ]
        expected_output_conditions = Program.to([aggsig_condition] + conditions)
        assert bytes(output) == bytes(expected_output_conditions)

    def test_just_rate_limit_layer(self):
        seconds_per_interval, mojos_per_interval, zero_date = 100, 333, 864000
        rate_limit_layer = rate_limit_validation.layer_puzzle(
            seconds_per_interval, mojos_per_interval, zero_date
        )
        rate_limit_puzzle = rate_limit_layer.at("f")
        rate_limit_curry_parameters = rate_limit_layer.at("r")
        fake_output_address = bytes32([0] * 32)
        now = 12345
        interval_count = math.ceil((zero_date - now) / seconds_per_interval)
        min_change_amount = interval_count * mojos_per_interval
        change_amount = min_change_amount + 1000

        inner_puzzle = ANYONE_CAN_SPEND_PUZZLE

        pay_to_layer_list = [rate_limit_layer, Program.to((inner_puzzle, 0))]
        change_puzzle = validating_meta_puzzle.puzzle_for_layers(pay_to_layer_list)
        change_puzzle_hash = change_puzzle.tree_hash()
        conditions = Program.to(
            [
                [81, now],
                [51, fake_output_address, 1007],
                [51, change_puzzle_hash, change_amount],
                [1, "junk", 1001],
            ]
        )

        # success case
        assert_later_condition_index = 0
        change_condition_index = 2
        change_validating_puzzle_index = 0
        validating_puzzle_hash_list = [_.tree_hash() for _ in pay_to_layer_list]
        rate_limit_solution = rate_limit_validation.solution_for_layer(
            seconds_per_interval,
            mojos_per_interval,
            zero_date,
            now,
            assert_later_condition_index,
            change_condition_index,
            change_validating_puzzle_index,
            validating_puzzle_hash_list,
        )
        composite_solution = merge_list(
            rate_limit_curry_parameters, rate_limit_solution
        )

        args = Program.to((conditions, composite_solution))
        r = run_validator(rate_limit_puzzle, args)


def merge_list(l1: Program, l2: Program) -> Program:
    if l1.pair is None:
        return l2
    return Program.to((l1.pair[0], merge_list(l1.pair[1], l2)))
