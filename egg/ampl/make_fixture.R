# Writes a small fixture (.dat) and the expected optimum from an independent R dynamic programme (exact, O(n^2)).
set.seed(20000401); x <- c(rnorm(30), rnorm(30, 1.2), rnorm(30)); n <- length(x); m <- 10L; beta <- 8
S <- c(0, cumsum(x)); F <- rep(Inf, n + 1); F[1] <- 0; last <- integer(n + 1)
for (b in m:n) for (a in 0:(b - m)) if (is.finite(F[a + 1])) { v <- F[a + 1] - (S[b + 1] - S[a + 1])^2 / (b - a) + beta; if (v < F[b + 1]) { F[b + 1] <- v; last[b + 1] <- a } }
cp <- c(); t <- n; while (t > 0) { a <- last[t + 1]; if (a > 0) cp <- c(a, cp); t <- a }
out <- c(sprintf("param n := %d;", n), sprintf("param MINSEG := %d;", m), sprintf("param beta := %g;", beta), "param S :=", sprintf("%d %.12g", 0:n, S), ";")
writeLines(out, "ampl/fixture.dat")
writeLines(c(sprintf("expected_objective\t%.10f", F[n + 1]), sprintf("expected_changepoints\t%s", paste(cp, collapse = ","))), "ampl/fixture_expected.tsv")
cat(readLines("ampl/fixture_expected.tsv"), sep = "\n")
