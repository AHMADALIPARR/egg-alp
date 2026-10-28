# Deliverable 7: change-point candidates with calibrated significance.
# Series: network Z + 25 device z series. Missing cells are compressed OUT (never filled); reported times map back to UTC seconds.
# 1) CUSUM (bridge form: max_k |S_k - k/n S_n| / sqrt(n)), p-values from exact-binomial null simulations.
#    Null series have the same missingness structure: network Z sims reuse the real per-second |V_t| (sum ~ Binomial(200 k_t, 1/2));
#    device sims have the same number of observed cells. BH over the 26 series.
# 2) Penalized likelihood: optimal partitioning with PELT pruning, normal-mean cost, known variance 1, minimum segment 60 s.
#    Penalty beta = (1 - 0.05/26) quantile of the null distribution of the best single-split likelihood gain => family-wise
#    false-positive rate about 5% over the 26 series under H0. Sensitivity: beta x 0.5 ... x 2 and 2*log(n).
# No holdout date exists in this repo: everything here is EXPLORATORY. Nothing is confirmed.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
dd <- read_dense(); X <- dd$X; ids <- dd$ids; Tn <- nrow(X); nd <- ncol(X); t0 <- dd$t[1]
ns <- read.delim(file.path(D$out, "r", "network_z_series.tsv")); kt <- ns$k
MINSEG <- 60L
series <- c(list(list(name = "network", x = ns$Z, idx = seq_len(Tn), kind = "net")),
  lapply(seq_len(nd), function(i) { o <- which(!is.na(X[, i])); list(name = ids[i], x = z_of(X[o, i]), idx = o, kind = "dev") }))
utc <- function(i) format(as.POSIXct(t0 + i - 1, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d %H:%M:%S")
cusum <- function(x) { n <- length(x); S <- cumsum(x); k <- seq_len(n - 1); b <- abs(S[k] - k / n * S[n]) / sqrt(n); w <- which.max(b); c(stat = b[w], loc = w) }
gain_max <- function(x) { n <- length(x); S <- cumsum(x); k <- MINSEG:(n - MINSEG); max(S[k]^2 / k + (S[n] - S[k])^2 / (n - k) - S[n]^2 / n) }
sim_series <- function(s) if (s$kind == "net") (rbinom(Tn, 200L * kt, 0.5) - 100 * kt) / sqrt(50 * kt) else (rbinom(length(s$x), 200L, 0.5) - 100) / sqrt(50)
B <- 4000L
# simulate once per distinct null structure
keys <- sapply(series, function(s) if (s$kind == "net") "net" else as.character(length(s$x))); ukeys <- unique(keys)
nullstats <- list()
for (ky in ukeys) { s <- series[[which(keys == ky)[1]]]; set.seed(seed_for(paste0("cp-null-", ky)))
  m <- vapply(seq_len(B), function(b) { z <- sim_series(s); c(cusum(z)[1], gain_max(z)) }, numeric(2)); nullstats[[ky]] <- m }
obs <- do.call(rbind, lapply(seq_along(series), function(i) { s <- series[[i]]; cu <- cusum(s$x); ns_ <- nullstats[[keys[i]]]
  g <- gain_max(s$x); beta <- quantile(ns_[2, ], 1 - 0.05 / length(series), names = FALSE)
  data.frame(series = s$name, n_observed = length(s$x), cusum_stat = cu[1], cusum_time_utc = utc(s$idx[cu[2]]), cusum_idx = s$idx[cu[2]],
    p_cusum = (1 + sum(ns_[1, ] >= cu[1])) / (B + 1), best_split_gain = g, p_gain = (1 + sum(ns_[2, ] >= g)) / (B + 1), beta_calibrated = beta) }))
obs$q_cusum_BH <- p.adjust(obs$p_cusum, "BH"); obs$q_gain_BH <- p.adjust(obs$p_gain, "BH")
obs$p_cusum_bonferroni <- pmin(1, obs$p_cusum * nrow(obs))
# ---- PELT (min segment MINSEG), cost c(a..b) = -(S_b - S_{a-1})^2/len
pelt_R <- function(x, beta, m = MINSEG) {
  n <- length(x); S <- c(0, cumsum(x)); F <- numeric(n + 1); F[1] <- -beta; last <- integer(n + 1); R <- integer(0)
  cst <- function(tau, t) -(S[t + 1] - S[tau + 1])^2 / (t - tau)
  for (t in m:n) { R <- c(R, t - m); cand <- R; v <- F[cand + 1] + cst(cand, t) + beta; j <- which.min(v); F[t + 1] <- v[j]; last[t + 1] <- cand[j]
    R <- cand[F[cand + 1] + cst(cand, t) <= F[t + 1]] }                 # prune (K = 0)
  cp <- integer(0); t <- n; while (t > 0) { tau <- last[t + 1]; if (tau > 0) cp <- c(tau, cp); t <- tau }; cp }
# C version of the same algorithm (R is too slow for ~250 runs of n = 86400); checked against pelt_R on small series first
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
dir.create(file.path(D$out, "bin"), showWarnings = FALSE, recursive = TRUE)
so <- file.path(D$out, "bin", "pelt.so"); system2("gcc", c("-O2", "-shared", "-fPIC", "-o", so, file.path(here, "pelt.c")))
dyn.load(so)
pelt <- function(x, beta, m = MINSEG) { r <- .C("pelt_c", as.double(x), as.integer(length(x)), as.double(beta), as.integer(m), cp = integer(length(x) %/% m + 1L), nc = integer(1)); r$cp[seq_len(r$nc)] }
set.seed(seed_for("cp-pelt-selftest")); selftest <- vapply(1:6, function(b) { x <- c(rnorm(700), rnorm(500, 0.4 * (b %% 3)), rnorm(600)); identical(as.integer(pelt(x, 9, 60L)), as.integer(pelt_R(x, 9, 60L))) }, logical(1))
cat("PELT C vs R reference on 6 small series identical:", all(selftest), "\n"); stopifnot(all(selftest))
mults <- c(0.5, 0.75, 1, 1.5, 2)
NC <- 6L   # PELT has no randomness, so running the series in parallel (forked) gives the same answer as a serial loop
one <- function(i) { s <- series[[i]]; beta <- obs$beta_calibrated[i]; n <- length(s$x); sens <- list(); cand <- list()
  for (mu in mults) { cp <- pelt(s$x, beta * mu); sens[[length(sens) + 1]] <- data.frame(series = s$name, beta_multiplier = mu, beta = beta * mu, n_changepoints = length(cp)) }
  cp <- pelt(s$x, 2 * log(n)); sens[[length(sens) + 1]] <- data.frame(series = s$name, beta_multiplier = NA, beta = 2 * log(n), n_changepoints = length(cp))
  cp <- pelt(s$x, beta)
  if (length(cp)) { b <- c(0, cp, n); for (j in seq_along(cp)) { l <- (b[j] + 1):b[j + 1]; r <- (b[j + 1] + 1):b[j + 2]
      cand[[length(cand) + 1]] <- data.frame(series = s$name, changepoint_time_utc = utc(s$idx[cp[j]]), idx_in_series = cp[j], mean_before = mean(s$x[l]), mean_after = mean(s$x[r]),
        shift_in_sd_units = mean(s$x[r]) - mean(s$x[l]), len_before = length(l), len_after = length(r), beta = beta) } }
  list(sens = do.call(rbind, sens), cand = if (length(cand)) do.call(rbind, cand) else NULL) }
res <- parallel::mclapply(seq_along(series), one, mc.cores = NC); stopifnot(!any(vapply(res, function(r) inherits(r, "try-error") || is.null(r), logical(1))))
sens <- lapply(res, `[[`, "sens"); cand <- Filter(Negate(is.null), lapply(res, `[[`, "cand"))
sens <- do.call(rbind, sens); cands <- if (length(cand)) do.call(rbind, cand) else data.frame(note = "no changepoints at the calibrated penalty in any of the 26 series")
# ---- false-positive check of the calibrated PELT on 40 fresh null series with the real network mask
set.seed(seed_for("cp-pelt-null")); nb <- 40L
nullser <- lapply(seq_len(nb), function(b) sim_series(series[[1]]))   # generated serially with the fixed seed, then analysed in parallel
fp <- unlist(parallel::mclapply(nullser, function(x) length(pelt(x, obs$beta_calibrated[1])), mc.cores = NC))
nullchk <- data.frame(check = "PELT at calibrated beta on fresh exact-binomial null network series (same |V_t| mask)", n_null_series = nb, series_with_any_changepoint = sum(fp > 0),
  mean_changepoints = mean(fp), beta = obs$beta_calibrated[1], c_vs_R_selftest_identical = all(selftest))
write_tsv_num(obs, "r_changepoint_cusum_gain.tsv"); write_tsv_num(sens, "r_changepoint_sensitivity.tsv"); write_tsv_num(cands, "r_changepoint_candidates.tsv"); write_tsv_num(nullchk, "r_changepoint_null_check.tsv")
cat("changepoint done\n"); print(obs[order(obs$p_cusum)[1:5], c("series", "cusum_stat", "cusum_time_utc", "p_cusum", "q_cusum_BH", "p_gain", "q_gain_BH", "beta_calibrated")])
print(cands); print(aggregate(n_changepoints ~ beta_multiplier, sens, sum)); print(sens[is.na(sens$beta_multiplier) & sens$n_changepoints > 0, ]); print(nullchk)
