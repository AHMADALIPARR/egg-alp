# egg/lean

Lean 4 (v4.35.0, core only, no Mathlib) lemmas in `EggLean/Nullable.lean`. VERIFIED by `lake build`: see `BUILD.log` (`make verify`).
No `sorry`; axioms used are only the standard core ones (propext, Classical.choice, Quot.sound), see `EggLean/Audit.lean` output in the log.

Proved: missing-not-zero, count partition, zero imputation changes count, 0..200 contract (sum <= 200 * count, Fin 201 typed cells),
network Z^2 only defined for count > 0, permutation invariance of sum/count/centered sum/network Z^2.

NOT proved (unproved statements, no claim): Shannon entropy bound 0 <= H <= log2 m (needs Mathlib `Real.log`, not in this build),
min-entropy bounds, binomial moments.
