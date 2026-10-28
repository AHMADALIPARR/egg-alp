# egg/dafny

Nullable device-count contracts for EGG-001 (`Nullable.dfy`). VERIFIED by Dafny 4.11.0: see `VERIFY.log` (`make verify`).

Proved: missing != zero, valid/missing counts partition cells, zero-imputation changes count,
sum/mean bounds over valid cells (0..200), network Z^2 precondition (|V_t| > 0, never divides by zero, bound Z^2 <= 200 n),
rolling-window qualification via prefix counts, permutation invariance of sum/count/network Z^2, row-validation method.

NOT done here: entropy bounds (0 <= H <= log2 n) - Dafny has no log. These are not claimed.
These proofs concern the specification's finite arithmetic, not the physical data.
