(mod (conditions
      CA
      now
      interval_count
      assert_later_condition_index
      change_condition_index
      change_validating_puzzle_index
      validating_puzzles_list)

      ;; CA = "curry arguments", which is
      ;; (VALIDATING_META_MOD MY_MOD SECONDS_PER_INTERVAL MOJOS_PER_INTERVAL ZERO_DATE)

  ;; this validating layer enforces a simple rate-limiting wallet that requires that the
  ;; a coin be created that holds the rate-limited amount. An interval is defined with
  ;; `SECONDS_PER_INTERVAL`. We see how many intervals there are from now to `ZERO_DATE`
  ;; and ensure the change is at least `MOJOS_PER_INTERVAL * interval_count`.
  ;; After time `ZERO_DATE` we no longer require a change.

  (include condition_codes.cl)

  (defun-inline CA_VALIDATING_META_MOD (CA) (f CA))
  (defun-inline CA_MY_MOD (CA) (f (r CA)))
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

  (defun calculate_validating_meta_puzzle_hash (CA_VALIDATING_META_MOD validating_puzzles_list)
  ;; (curry CA_VALIDATING_META_MOD validating_puzzles_list)
      1
  )

  (defun condition_for_index (conditions index)
      (if (= index 0) (f conditions) (condition_for_index (r conditions) (- index 1)))
  )

  (defun ensure_assert_later_exists (condition now)
      (all (= (f condition) ASSERT_SECONDS_ABSOLUTE) (not (> now (f (r condition)))))
  )

  (defun ensure_enough_change (CA amount interval_count now)
      (all (not (> (* (CA_MOJOS_PER_INTERVAL CA) interval_count) amount))
           (not (> (CA_ZERO_DATE CA) (+ (* (CA_SECONDS_PER_INTERVAL CA) interval_count) now)))
      )
  )

  (defun ensure_change_address_valid (CA change_puzzle_hash change_validating_puzzle_index validating_puzzles_list)
      (all (= change_puzzle_hash (calculate_validating_meta_puzzle_hash CA_VALIDATING_META_MOD validating_puzzles_list))
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
  
  (all (ensure_assert_later_exists (condition_for_index conditions assert_later_condition_index) now)
       (if (> now (CA_ZERO_DATE CA))
           1
           (ensure_change_valid CA
                                (fetch_coin_puzzle_hash_and_amount (condition_for_index conditions change_condition_index))
                                change_validating_puzzle_index
                                validating_puzzles_list
                                interval_count
                                now)
       )
  )
  ;;0)

)