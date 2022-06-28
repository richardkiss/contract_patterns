You now have a good grasp of ChiaLisp. But what do you do with it? Creating a contract can seem daunting at first, like a blank sheet of paper. Experience shows there are several useful patterns that recur when developing contracts for use with chia.

# Inner Puzzles

At its core, a puzzle expects a solution and it returns conditions. The format of the solution is completely unspecified. The format of the conditions is completely specified. A decent puzzle generally has some kind of lock to prevent mutable `CREATE_COIN` conditions from appearing in the set of output conditions, by using either `AGGSIG_ME` (or in very rare cases, `AGGSIG_UNSAFE`) or `ASSERT_*_ANNOUNCEMENT` (and the announcement creation must generally be locked somehow too).

This yields a small number of useful inner puzzle patterns.

`p2_conditions` [TK: link]

A coin that is in a "waiting room". It can only ever be spent one way. Usually doesn't have an `AGGSIG` in it, but might have an announcement assertion, or an announcement creation.

If it creates an puzzle hash announcement, it's probably a form of a `settlement_coin`, which acts as a witness that a particular payment as been made. Consider using the standard `settlement_coin`. [TK: need link]

## Single Public Key

A single public key can represent one entity, or it can require N-of-N agreement by simple `bls12_381` public key aggregation.

`p2_delegated_conditions` (Obsoleted by `p2_delegated_puzzle_and_hidden_puzzle`) [TK: link]

The first layer of delegation of the conditions that come out. This simple puzzle requires the conditions to be signed by a curried public key. That said, there is an obvious generalization, next.

`p2_delegated_puzzle` (Obsoleted by `p2_delegated_puzzle_and_hidden_puzzle`) [TK: link]

Instead of signing the conditions, sign another, even-more-inner puzzle that takes its own solution, and use that, adding an `AGGSIG_ME` condition to prove that the inner puzzle was blessed. By using a `p2_conditions` as the inner puzzle, this subsumes all the functionality provided by `p2_delegated_conditions`. This corresponds to bitcoin's graftroot.

`p2_delegated_puzzle_and_hidden_puzzle` [TK: link]

By adding a clever cryptographic trick to `p2_delegated_puzzle`, we also optionally allow a puzzle to be hidden inside the public key using what we call a "synthetic private key". This standard puzzle is in wide use in chia today, and makes `p2_delegated_puzzle` and `p2_delegated_conditions` obsolete as it optionally supports the features of both those puzzles.

In the case where no hidden puzzle is needed, and the creator wants to prove there is no hidden puzzle, the hidden puzzle of `(=)` or `(x)` can be used (which will always fail) and revealed. Finding additional hidden puzzles requires finding a sha256 collision (well, sort of... they need only collide mod the order of the groups of `bls12_381`, which doesn't make the problem a whole lot easier).

## Compound puzzles

`p2_one_of_n` [TK: link to not-yet-written puzzle]

If the single hidden puzzle made available by `p2_delegated_puzzle_and_hidden_puzzle` is insufficient, a puzzle that takes the root of a merkle tree of N puzzles is more flexible. This isn't a terminal inner puzzle per-se, but a layer around other inner puzzles that has the same API as an inner puzzle.

The solution provided to this puzzle is the selected inner puzzle along with a proof of inclusion in the merkle root, with the solution to the chosen puzzle, which is passed along to that chosen puzzle to produce conditions.

## Multisig

Often, M-of-N multisig where M < N (strictly less) is desired. There are two main ways of doing this:

`p2_m_of_n_delegate_direct` [TK: link]

The N keys are listed, and the M value named. A "selector" vector chooses which M keys are used, and the M `AGGSIG_ME` conditions generated. This doesn't require the M signers to know in advance which other signers will be signing.

`p2_m_of_n_merkle`

The $n \choose m$ different public key sums of M public keys are created, and put into a merkle tree. To spend, you extract the public key from the merkle tree and use it in `p2_delegated_puzzle_and_hidden_puzzle`. This method requires the M signers to know in advance which other signers will be signing.

## Announcements

Besides using `AGGSIG`, we might also use `ASSERT_*_ANNOUNCEMENT` to ensure that the coins created with `CREATE_COIN` are blessed by the appropriate entities.

`p2_singleton`

A singleton is a coin that has a traceable lineage back to its creation. A singleton lineage is parameterized by its "launcher" coin. A `p2_singleton` uses announcements from a singleton in a particular lineage.

A `p2_singleton` is tied to a particular singleton lineage and requires an announcement from that singleton lineage to be a has of the conditions returned.

A singleton that can take anything as an inner puzzle can act as dereferenced authentication, and be passed around as "deed" to coins locked with `p2_singleton`.

# Layered puzzles

Being Turning-complete, clvm allows for puzzles to be very complex. Modularity can be used to maximize audibility. Puzzle layer schemes fall into one of two categories: morphing, and validation.

## Morphing

A morphing layer expects conditions to be passed in, along with some (possibility farmer-mutable) solution data, and it returns conditions, possibly different. Generally it targets one or more conditions and validates or mutates them depending on the goal of that layer.

Information that we might not want to be farmer-mutable can be passed up from the inner puzzle in the form of bogus condition information that the mutating layer can strip out.

### Morphing Layer Example

The v1.1 singleton looks for `CREATE_COIN` conditions that have an odd amount, and it morphs the puzzle hash, wrapping it in a singleton (and enforces only one odd child is created).

## Validation

A validation layer examines conditions and verifying that meet some particular constraint that this validation layer is intended to enforce. Additional solution information might be included to help prove the constraint is valid (for example, a reveal of a puzzle hash to prove it meets a certain format).

A validation layer is given the opportunity to immediately fail with `(x)`, or any other fatal error. The return value should be ignored by the caller and is meaningless.

### Validation Layer Example

A rate-limiting wallet could apply validation to ensure that enough coins remain in the rate-limiting address to satisfy the requirements of rate-limiting. It could be passed the current time (which it could enforce by ensuring there is an `ASSERT_SECONDS_ABSOLUTE` condition) and use that to calculate the minimum mojos remaining, and check that a `CREATE_COIN` with the current address and that amount of mojos is being produced.


## Morphing vs Validation

As of this writing in June 2022, most of the existing chia contracts use morphing layers to implement their functionality. That said, using only validation layers provides some advantages, primarily with regard to composability.

First, note that a validation layer can be easily turned into a morphing layer by wrapping it in an adaptor that takes the conditions, calls the validation layer, then returns the conditions unchanged as the (un)"morphed" version. This is our first hint that writing layers as validators is preferable.

The two main advantages of validation over morphing are composability and commutativity.

### composability

Clearly, any list of validators can be included in any order, since they are all given the same inputs, and each is given a chance to fail the transaction. This also means that persistent validation -- that is, validators that check that child coins created also impose the same validation restrictions -- just means you need the validator as some layer SOMEWHERE.

### commutativity

Additionally, we can list the validators in any order, whereas morphing layers M1 and M2 may morph a subset of conditions in a conflicting way which could cause M1 • M2 ≠ M2 • M1.

But if V1 and V2 are validation layers, then V1 • V2 = V2 • V1.

# Validation Driver

We propose a meta-puzzle that takes a list of validators V1, V2, ..., Vn plus a single inner puzzle P that take a solution that contains N+1 sub-solutions for each layer. We call the inner puzzle P with its solution, returning a list of conditions. We in turn call each validator with the list of conditions, giving each in turn a chance to fail.

This means all validators all have the same API: accept a list of conditions plus a solution (which can be any clvm object and is specific to that validator), and return 0 (which is ignored) or raise an exception with (x).

**We might also consider returning 0 for failure or non-0 for success.**

In some cases, we may want to pass solution data that can't be morphed by farmers. (I can't think of a case where this would actually be necessary.) We declare a new condition code `REM` with value `1` (so it looks like `q`) which is guaranteed to always be ignored by the blockchain validation layer. The validation driver looks for the first instance of this special condition, and pulls of it N objects, one of each of which is passed to the N validation layers. If this data is missing, the default `0` is used.

So a validator looks like:

`(mod (conditions data condition_data)  ...)`

where `data` is mutable by farmers and `condition_data` comes out of the inner puzzle's conditions, and is thus presumably immutable by farmers (for secure inner puzzles).

The validation driver might also consider pre-computing values commonly used by validation puzzles and passing those values (akin to the "truths" concept used by many existing complex puzzles).

**It remains to be seen the usefulness of `condition_data` and `truths`.** We should write a bunch of validation puzzles to see if this would be useful.

## Code

```
(mod (PUZZLE_LIST_WITH_CURRY_PARAMETERS solutions)

  (defun merge_lists (L1 L2)
      (if L1
          (c (f L1) (merge_lists (r L1) L2))
          L2
      )
  )

  (defun run_inner_puzzle (puzzle_list solutions)
      (if (r puzzle_list)
          ; we are not there yet, keep digging
          (run_inner_puzzle (r puzzle_list) (r solutions))
          ; this is the inner puzzle!
          ; merge the curried parameters and the solution
          ; and run the inner puzzle
          (a (f (f puzzle_list)) (merge_lists (r (f puzzle_list)) (f solutions)))
      )
  )

  (defun run_validators (puzzle_list solutions (conditions . condition_summary))
      (
          (if (r puzzle_list)
              (assert (a (f (f puzzle_list)) (c condition_summary (merge_lists (r (f puzzle_list)) (f solutions))))
                      (run_validators (r puzzle_list) (r solutions) (c conditions condition_summary))
              )
              conditions
          )
      )
  )

  (defun build_condition_summary (conditions)
      ; we don't know what `condition_summary` should look like yet
      ; (or if it should even exist)
      ; this roughly corresponds to "truths"
      ; One thing we might do is dig out the `(REM)` condition and yield those
      ; parameters back to the validators in turn.
      ; This would make this puzzle a bit more complicated (but still very general).
      (c conditions 0)
  )

  (defun main (puzzle_list solutions)
     (run_validators puzzle_list solutions (build_condition_summary (run_inner_puzzle puzzle_list solutions)))
  )

  (main PUZZLE_LIST_WITH_CURRY_PARAMETERS solutions)
)
```

All validation layers expect the same inputs and produce the same outputs. This simplifies auditing since an auditor already knows what's going in and coming out. This also allows fuzzers to be written.

# Morphing Driver

Seeing the validation driver, we realize we can write a morphing driver template that has a similar API: take a list of N morphing layers, terminating in a single inner puzzle, and accept a list of N+1 solutions. Call the inner puzzle with the last solution, and pass the conditions up through each morphing layer until we reach the top.

A very common morphing layer patter is to look for `CREATE_COIN` conditions and morph the puzzle hash. We can have the driver also look for `CREATE_COIN` conditions, and if it sees a clvm tree as the puzzle hash, treat it as a list of driver template hashes and parameter tree hashes. This make it a lot easier for a morphing layer to ensure that the created coin also has the same morphing layer, like how singletons and CATs work.

Example:

```
(defun morph_puzzle_hash (my_mod_hash curried_parameters current_puzzle_hash)
   (c (sha256 2 (my_mod_hash (sha256tree current_parameters))) current_puzzle_hash)
)
```

So the inner puzzle might return `((CREATE_COIN 0x5555...5 100))` and the bottom-most layer puzzle might morph it to `((CREATE_COIN (0x3321323..37ae 0x5555...5) 100))`. So now the puzzle hash is the compound value `(0x3321323..37ae 0x5555...5)`. The driver puzzle knows this means "please embed me in this same driver" and flattens it out the a driver puzzle with the given layers and inner puzzle.

The driver should require that `CREATE_COIN` conditions that come out of the inner puzzle be atoms to prevent HSM shenanigans, as a simplified HSM might just work with inner puzzles and the conditions that come out, and be confused by a tree after `CREATE_COIN`.



------------------
BRAINSTORM

PUZZLE LAYERS:

BOTTOM-MOST INNER PUZZLE:

- `p2_conditions`
  - used by settlement coins
- `p2_delegated_conditions`
- `p2_delegated_puzzle`
- `p2_hidden_puzzle`
- `p2_delegated_puzzle_or_hidden_puzzle`
- `p2_m_of_n_direct`
- `p2_one_of_n` (merkle tree of puzzles)
- `p2_singleton` (listen for announcement rather than use a pubkey)
  - maybe a more general `p2_puzzle_announcement` and `p2_coin_announcement`?


MORPHING/FILTER LAYER:

- condition_augmenter
  - prepend a fixed set of conditions

- singleton_morpher (exists)
  - ensures exactly one odd output, also of singleton form

- singleton_filter

- cat morpher (exists)

- cat filter

- rate-limiting

TOP-MOST PUZZLE:

- morph driver
- filter driver

SPECIAL SPEND TYPES:

- singleton

- drop coin

- launcher

- rate-limiting

- settlement_coin
  - pays to notarized payment tree: `(nonce . ((puzzle_hash amount ...) (puzzle_hash amount ...) ...))`

- cat spend
  - creates the circle of coins


LAYER:

- arbitrary data

- merkle parameters layer


FILTER LAYER:

drop coin

inner puzzle

layer puzzle

morphing layer puzzle

validation layer puzzle

rate limiting

settlement coin

merkle parameters

p2_ach

SIGNATURE vs ANNOUNCEMENT



smart coin
smart scheme
protocol

stake pool airdrop for





Complex Chialisp programs that feature multiple swappable layers quickly become intractable to comprehend and audit. We propose a standardized metaprogram that allows arbitrary layers to be plugged in and a standard API for these layers.

A puzzle takes a solution, which can be anything, and returns a list of conditions which are evaluated by the consensus layer.

Layers generally restrict coin creation by examining the created coins and making sure they meet layer-specific requirements. For example, a single ensures only one child is also a singleton. Layer puzzles generally take a solution (possibly empty), then call out to the lower layer and get the conditions back, and optionally modify or validate the conditions passed back. If the lower layer needs to communicate with a higher layer (with information that's hashed and signed to prevent immutability, for example), it must do so by passing back "magic" conditions that are ignored by or never reach the consensus layer, and instead are intended to communicate with the layer above.

Let's fix how a lower layer passes in this information. We designate a single "magic" condition that takes an arbitrary number of arguments, and each argument is stripped off by the layer before being passed to the layer above. So if the bottom-most puzzle has four layers above it, and it returns conditions `((0 L3 L2 L1 L0) ...[real conditions] ...)`, the layer above it can look at L3, then morph the `0` condition to `(0 L2 L1 L0)`. Layers above the L3 layer never need to know what message was passed to L3.

We create a top-level meta-puzzle that looks like this:

```
(mod (LAYER_PUZZLES
      solutions_for_layer_puzzles
     )
...
)
```

where `LAYER_PUZZLES` is a list of puzzle templates along with the curried parameters.

The last puzzle in `LAYER_PUZZLES` must be an "inner puzzle", such as `p2_delegated_puzzle_or_hidden_puzzle`.

This meta-puzzle iterates over the both the `LAYER_PUZZLES` and `solutions_for_layer_puzzles` lists in parallel (like python's `zip` function) and invokes each layer puzzle with the curried parameters and the solution. It starts with the last, innermost "inner" puzzle, passing in the solutions, collecting the conditions, then passing the current conditions and solution to the layer above, which morphs the conditions for presentation to the layer above. Repeat until we reach the top layer. The final conditions are returned to the consensus layer.

Since it's so common to morph `CREATE_COIN` addresses, usually by wrapping them in new templates, we provide a native way of doing that here. A `(CREATE_COIN address amount)` value where `address` is an atom acts as normal. But we support recognizing non-atom addresses at the top layer, which look like ```((NEW_LAYER_PUZZLE_TEMPLATE_HASH . curried_parameters) inner_puzzle_hash)``` and the meta-puzzle will simplify it to a new address.