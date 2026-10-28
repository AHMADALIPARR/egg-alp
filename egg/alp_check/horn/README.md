# EGG-001 ALP contracts — checker (`egg/alp_check/horn`, contracts in `egg/contracts/horn`)

`make check` (in this directory) builds the **unmodified** `alp/` engine (`libalp_logic.a`) if needed, regenerates
facts from `egg/results/*.tsv` with `gen_facts.sh` (awk + shell, no other deps), compiles `check_driver.cpp`,
and runs: (1) real facts — must give 0 violations; (2) `negative/negative.alp` overlay — must flag every id on its
`% EXPECT-IC:` line; (3) three `sed` mutations of the real facts — each must be flagged. Output: `CHECK.log`.
Exit code 0 only if all three pass. `alp/` was not changed.

## What the ALP dialect really is (from `alp/src/parser.cpp`)
* Statements: `fact.`  `head <- b1, not b2.`  `false <- b1, not b2.` (integrity constraint)  `abducible(p).`
* Identifier chars `[A-Za-z0-9_-]`; uppercase first letter = variable; digits / lowercase-first = constant. No `.` inside a token
  (so `0.05` is written `0p05`), no `_` wildcard, `%` comments.
* The parser strips the prefixes `not`, `false`, `abducible` from tokens: **predicate names must not start with them**.
* **There is no arithmetic and no comparison.** Equality is unification (repeated variable); a range is an enumerated domain
  (`count_domain(0..200)`, 201 facts); `<=`, `+`, `=` over numbers are **precomputed by `gen_facts.sh`** into flag facts
  (`within_utc_day/1`, `dev_rows_balance/1`, `hist_ok`, `entropy_bounds_ok/1`, `hmin_le_h/1`, `pearson_df_ok/1`, `rowvalid_total_ok`, …)
  and the contracts only join / negate them. So the logic checks *consistency of recomputed facts and claims*; the numeric recomputation itself is awk.
* Negation as failure; the engine is a naive fixed point (no predicate index). Note `InferenceEngine::query` recomputes a fixed point,
  so `alp::violations` is very slow on ~1500 facts; the driver therefore does its own constraint evaluation (same unify loop) over a single closure.
* The parser discards comments, so the driver labels each one-line `false <-` with the `% IC <id>: text` comment above it (count mismatch = error).

## Contracts (`egg/contracts/horn`)
| file | content |
|---|---|
| `00_domain.alp` | `count_domain(0..200)` |
| `10_data_contract.alp` | valid count in 0..200, missing explicit (never zero, no imputation, zero-imputation signature), UTC day bounds, stable device ids/positions, source SHA-256, one CSV, synthetic never "physical" |
| `20_invariants.alp` | network-Z precondition (no empty valid set; empty ⇒ undefined), entropy preconditions/bounds, Pearson df, null/H0/H1 gates (H1 needs requirements + holdout), test plan facts (null, correction, seed, preregistration) |
| `30_claims.alp` | claim registry; **verified** = recomputed result with evidence that holds in the fact set; **hypothesis** = needs a `tests_claim` or `blocked_by`; **unverified** = implementation/proof/replication claim with `missing_evidence`; exclusive; formal-proof/replication/scientific-hypothesis never verified without artifact |
| `50_policy.alp` | no LLM/agent/token-sampler/trainer runtime component, no consciousness/simulation/causal assertion, no invented or unsourced event data (event count 0, events need independent UTC source) |

## Honest limits
* Lean/Dafny/AMPL/SAS/T-SQL/Elixir/MATLAB claims are `unverified` here: the checker sees that artifacts exist but does not run those tools.
* The policy scan (`policy_hit`) is a line-grep heuristic with a negation filter (`negated` vs `asserted`), not semantic.
* Engine pitfall found while building this: `InferenceEngine::derive_once` evaluates `not q` against the closure of the *same* pass (no stratification),
  so a rule that negates a derived predicate fires spuriously (my first `test_not_run` rule flagged all 10 tests). Rules here negate only EDB
  facts; derived predicates are negated only inside integrity constraints, which are evaluated after the fixed point.
* `test_executed/1` is derived from `result_file/1` (result TSV with data rows). t10's output (`r_changepoint_candidates`) is absent from egg/results, so t10
  is not executed; no verified claim may depend on it (`cl_verified_depends_on_unrun_test`).
* Negative overlay facts are synthetic test inputs, not data, and are never produced by `gen_facts.sh`.
* A concurrent worker created `egg/contracts/{data_contract,invariants,claims_policy}.alp` and `egg/alp_check/{alp_check.cpp,run.sh}`; these
  were left untouched and this set lives in the `horn/` subdirectories to avoid collisions.
