(mod (conditions condition_index witness_1 witness_2)

  ;; this validating layer requires that a condition have an output that is not prime
  ;; We do this by passing in the `condition_index` (a value N which picks out the Nth
  ;; condition, which must be `CREATE_COIN`) and two witnesses > 1 which multiply
  ;; to the amount of the `CREATE_COIN`

  (include condition_codes.cl)

  (defmacro assert items
      (if (r items)
          (list if (f items) (c assert (r items)) (q . (x)))
          (f items)
      )
  )

  ;(defun-inline create_coin_amount (condition)
  (defun create_coin_amount (condition)
      (assert (= CREATE_COIN (f condition))
              (f (r (r condition)))
      )
  )

  (defun find_create_coin_amount (conditions condition_index)
         (if condition_index
           (find_create_coin_amount (r conditions) (- condition_index 1))
           (create_coin_amount (f conditions))
         )
  )


  (defun main (conditions condition_index witness_1 witness_2)

  (all (= (* witness_1 witness_2) (find_create_coin_amount conditions condition_index))
       (> witness_1 1)
       (> witness_2 1)
  )
  )
  ;(x condition_index) ; 
  (main conditions condition_index witness_1 witness_2)

)