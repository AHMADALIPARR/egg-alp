AMPL files: `segmentation.mod` + `fixture.dat`, expected optimum in `fixture_expected.tsv` (from an exact R dynamic programme).
UNVERIFIED-NOT-RUN: no AMPL or solver on this machine. To check on a machine that has one:
`ampl: model segmentation.mod; data fixture.dat; option solver highs; solve; display total;` — the objective must equal `expected_objective`.
AMPL is not used for the real-data results. Those use PELT in R (C helper).
