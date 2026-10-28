# EGG-001 ALP contracts

The contracts are `.alp` Horn-clause programs in `horn/` (`00_domain`, `10_data_contract`, `20_invariants`,
`30_claims`, `50_policy`). They run on the unmodified `alp/` engine. The checker, fact generator and tests are in
`egg/alp_check/horn/`; its README lists the contracts and the engine pitfalls in detail.

Run `egg/alp_check/run.sh`. It builds the engine, regenerates facts from `egg/results/*.tsv`, and runs the real facts
(0 violations required) plus a negative overlay and three mutations (all must be flagged). It exits nonzero on any
failure and saves its output to `egg/results/alp_check.txt`.

## Dialect limits (from `alp/src/parser.cpp`)
- Supported: ground and variable facts, Horn rules, negation as failure, `false <- body.` integrity constraints,
  and unification as equality.
- Not supported: arithmetic, comparison (`<`, `>=`), decimals, strings, aggregates, an anonymous `_`,
  and stratified negation.
- So `0 <= count <= 200`, valid+missing = 86400, UTC-day bounds, `H <= log2(201)`, `Hmin <= H` and similar numeric facts
  are computed by the fact generator (`gen_facts.sh`, awk) into flag facts. The contracts only join or negate those flags.
  The logic checks consistency of the recomputed facts and claims. It does not recompute the numbers itself.
- Parser quirk: predicate names must not start with `not`, `false` or `abducible`.

## Honest limits
- Lean, Dafny, AMPL, SAS, T-SQL and Elixir results are classified `unverified` by the contracts. The checker only sees
  that their artifacts exist. It does not run those tools.
- The policy scan (LLM/agent/consciousness/simulation terms) is a line-grep heuristic with a negation filter.
- Tests are "documented, not pre-registered", and the contracts enforce that wording. The repo has no holdout date,
  so H1 cannot be marked established.
