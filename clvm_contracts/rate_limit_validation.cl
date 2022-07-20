(mod (conditions
      CA
      now
      interval_count
      assert_later_condition_index
      change_condition_index
      change_validating_puzzle_index
      validating_puzzles_list)

      ;; CA = "curry arguments", which is
      ;; (VALIDATING_META_MOD_HASH MY_MOD_HASH SECONDS_PER_INTERVAL MOJOS_PER_INTERVAL ZERO_DATE)

  ;; this validating layer enforces a simple rate-limiting wallet that requires that the
  ;; a coin be created that holds the rate-limited amount. An interval is defined with
  ;; `SECONDS_PER_INTERVAL`. We see how many intervals there are from now to `ZERO_DATE`
  ;; and ensure the change is at least `MOJOS_PER_INTERVAL * interval_count`.
  ;; After time `ZERO_DATE` we no longer require a change.

  ;; `now` : current time. We require an `ASSERT_SECONDS_ABSOLUTE` condition
  ;; `interval_count` : intervals (each `CA_SECONDS_PER_INTERVAL` seconds long) prior to `now`. Round up.
  ;; `assert_later_condition_index`: index of condition with the `ASSERT_SECONDS_ABSOLUTE` condition
  ;; `change_condition_index`: index of condition with `CREATE_COIN` of sufficient change
  ;; `change_validating_puzzle_index`: index of `validating_puzzles_list` that corresponds to this validator
  ;; `validating_puzzles_list`: list of puzzles change addresses curried to the validating metapuzzle

  (include condition_codes.cl)
  (include sha256tree.cli)

  (defun-inline CA_VALIDATING_META_MOD_HASH (CA) (f CA))
  (defun-inline CA_MY_MOD_HASH (CA) (f (r CA)))
  (defun-inline CA_SECONDS_PER_INTERVAL (CA) (f (r (r CA))))
  (defun-inline CA_MOJOS_PER_INTERVAL (CA) (f (r (r (r CA)))))
  (defun-inline CA_ZERO_DATE (CA) (f (r (r (r (r CA))))))

  (defmacro assert items
      (if (r items)
          (list if (f items) (c assert (r items)) (q . (x)))
          (f items)
      )
  )

  (defun fetch_coin_puzzle_hash_and_amount (condition)
      ;; return `(puzzle_hash amount)`
      (assert (= CREATE_COIN (f condition))
              (r condition)
      )
  )

  (defun sha256treehash_cons_list (list_of_hashes)
    (if list_of_hashes
        (sha256 2
                (f list_of_hashes)
                (sha256treehash_cons_list (r list_of_hashes))
        )
        (sha256 1 0)
    )
  )

  (defun calculate_validating_meta_puzzle_hash (CA_VALIDATING_META_MOD_HASH list_of_hashes)
    ;; (curry CA_VALIDATING_META_MOD_HASH list_of_hashes)
    ;; (a (q . CA_VALIDATING_META_MOD_HASH) (c (q . list_of_hashes) 1))
    ;; TODO: optimize this with memoized values for `(sha256 1 #op)` op in [a, q, c, 0]
    (sha256 2
            (sha256 1 #a)
            (sha256 2
                    (sha256 2 (sha256 1 #q) CA_VALIDATING_META_MOD_HASH)
                    (sha256 2
                            (sha256 2
                                    (sha256 1 #c)
                                    (sha256 2
                                            (sha256 2 (sha256 1 #q) (sha256treehash_cons_list list_of_hashes))
                                            (sha256 2 (sha256 1 1) (sha256 1 0))
                                    )
                            )
                            (sha256 1 0)
                    )
            )
    )
  )

  (defun item_at_index (items index)
      (if (= index 0) (f items) (item_at_index (r items) (- index 1)))
  )

  (defun ensure_assert_later_exists (condition now)
      (all (= (f condition) ASSERT_SECONDS_ABSOLUTE) (not (> now (f (r condition)))))
  )

  (defun ensure_enough_change (CA amount interval_count now)
      (all (not (> (* (CA_MOJOS_PER_INTERVAL CA) interval_count) amount))
           (not (> (CA_ZERO_DATE CA) (+ (* (CA_SECONDS_PER_INTERVAL CA) interval_count) now)))
      )
  )

  (defun dsha256 V
    (a (c (list sha256) V) 1)
  )

  (defun ensure_rate_limit_validator_in_validator_list (CA validating_puzzles_list change_validating_puzzle_index)
     (= (item_at_index validating_puzzles_list change_validating_puzzle_index)
        (sha256 2 (CA_MY_MOD_HASH CA) (sha256tree (list CA)))
     )
  )

  ;; check that the puzzle hash for the `CREATE_COIN` change address is a validating meta-puzzle with the
  ;; given list of validating puzzles
  (defun ensure_change_puzzle_hash_correct (CA change_puzzle_hash validating_puzzles_list)
      (= change_puzzle_hash (calculate_validating_meta_puzzle_hash (CA_VALIDATING_META_MOD_HASH CA) validating_puzzles_list))
  )

  (defun ensure_change_address_valid (CA change_puzzle_hash change_validating_puzzle_index validating_puzzles_list)
      (all (ensure_change_puzzle_hash_correct CA change_puzzle_hash validating_puzzles_list)
           (ensure_rate_limit_validator_in_validator_list CA validating_puzzles_list change_validating_puzzle_index)
      )
  )

  (defun ensure_change_valid (CA
                              (change_puzzle_hash amount)
                              change_validating_puzzle_index
                              validating_puzzles_list
                              interval_count
                              now)
      (all (ensure_change_address_valid CA change_puzzle_hash change_validating_puzzle_index validating_puzzles_list)
           (ensure_enough_change CA amount interval_count now)
      )
  )

  ;; there are a few things to check
  ;;(if (x validating_puzzles_list)
  
  (all (ensure_assert_later_exists (item_at_index conditions assert_later_condition_index) now)
       (if (> now (CA_ZERO_DATE CA))
           1
           (ensure_change_valid CA
                                (fetch_coin_puzzle_hash_and_amount (item_at_index
                                                                    conditions
                                                                    change_condition_index))
                                change_validating_puzzle_index
                                validating_puzzles_list
                                interval_count
                                now)
       )
  )
  ;;0)

)