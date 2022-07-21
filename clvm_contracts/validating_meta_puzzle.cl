(mod (PUZZLE_LIST_WITH_CURRY_PARAMETERS solutions)
  ; PUZZLE_LIST_WITH_CURRY_PARAMETERS = (PC1 PC2 PC3 ... PCN)
  ; where PC_k = (puzzle_template . curried_values)

  (defmacro assert items
      (if (r items)
          (list if (f items) (c assert (r items)) (q . (x)))
          (f items)
      )
  )

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
      (if (r puzzle_list)
          (assert (a (f (f puzzle_list)) (c conditions (merge_lists (r (f puzzle_list)) (f solutions))))
                  (run_validators (r puzzle_list) (r solutions) (c conditions condition_summary))
          )
          conditions
      )
  )

  (defun-inline build_condition_summary (conditions)
      ; we don't know what `condition_summary` should look like yet
      ; (or if it should even exist)
      ; this roughly corresponds to "truths"
      ; One thing we might do is dig out the `(REM)` condition and yield those
      ; parameters back to the validators in turn.
      ; This would make this puzzle a bit more complicated (but still very general).
      ; for now, let's just use an empty list
      (c conditions 0)
  )

  (run_validators PUZZLE_LIST_WITH_CURRY_PARAMETERS
                  solutions
                  (build_condition_summary (run_inner_puzzle PUZZLE_LIST_WITH_CURRY_PARAMETERS solutions))
  )
)
