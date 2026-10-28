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
pelt <- function(x, beta, m = MINSEG) {
  n <- length(x); S <- c(0, cumsum(x)); F <- numeric(n + 1); F[1] <- -beta; last <- integer(n + 1); R <- integer(0)
  cst <- function(tau, t) -(S[t + 1] - S[tau + 1])^2 / (t - tau)
  for (t in m:n) { R <- c(R, t - m); cand <- R; v <- F[cand + 1] + cst(cand, t) + beta; j <- which.min(v); F[t + 1] <- v[j]; last[t + 1] <- cand[j]
    R <- cand[F[cand + 1] + cst(cand, t) <= F[t + 1]] }                 # prune (K = 0)
  cp <- integer(0); t <- n; while (t > 0) { tau <- last[t + 1]; if (tau > 0) cp <- c(tau, cp); t <- tau }; cp }
mults <- c(0.5, 0.75, 1, 1.5, 2)
pel <- list(); sens <- list(); cand <- list()
for (i in seq_along(series)) { s <- series[[i]]; beta <- obs$beta_calibrated[i]; n <- length(s$x); S <- cumsum(s$x)
  for (mu in mults) { cp <- pelt(s$x, beta * mu); sens[[length(sens) + 1]] <- data.frame(series = s$name, beta_multiplier = mu, beta = beta * mu, n_changepoints = length(cp)) }
  cp <- pelt(s$x, 2 * log(n)); sens[[length(sens) + 1]] <- data.frame(series = s$name, beta_multiplier = NA, beta = 2 * log(n), n_changepoints = length(cp))
  cp <- pelt(s$x, beta)
  if (length(cp)) { b <- c(0, cp, n); for (j in seq_along(cp)) { l <- (b[j] + 1):b[j + 1]; r <- (b[j + 1] + 1):b[j + 2]
      cand[[length(cand) + 1]] <- data.frame(series = s$name, changepoint_time_utc = utc(s$idx[cp[j]]), idx_in_series = cp[j], mean_before = mean(s$x[l]), mean_after = mean(s$x[r]),
        shift_in_sd_units = mean(s$x[r]) - mean(s$x[l]), len_before = length(l), len_after = length(r), beta = beta) } } }
sens <- do.call(rbind, sens); cands <- if (length(cand)) do.call(rbind, cand) else data.frame(note = "no changepoints at the calibrated penalty in any of the 26 series")
# ---- false-positive check of the calibrated PELT on 40 fresh null series with the real network mask
set.seed(seed_for("cp-pelt-null")); nb <- 40L
fp <- sapply(seq_len(nb), function(b) length(pelt(sim_series(series[[1]]), obs$beta_calibrated[1])))
nullchk <- data.frame(check = "PELT at calibrated beta on fresh exact-binomial null network series (same |V_t| mask)", n_null_series = nb, series_with_any_changepoint = sum(fp > 0),
  mean_changepoints = mean(fp), beta = obs$beta_calibrated[1])
write_tsv_num(obs, "r_changepoint_cusum_gain.tsv"); write_tsv_num(sens, "r_changepoint_sensitivity.tsv"); write_tsv_num(cands, "r_changepoint_candidates.tsv"); write_tsv_num(nullchk, "r_changepoint_null_check.tsv")
cat("changepoint done\n"); print(obs[order(obs$p_cusum)[1:5], c("series", "cusum_stat", "cusum_time_utc", "p_cusum", "q_cusum_BH", "p_gain", "q_gain_BH", "beta_calibrated")])
print(cands); print(aggregate(n_changepoints ~ beta_multiplier, sens, sum)); print(sens[is.na(sens$beta_multiplier) & sens$n_changepoints > 0, ]); print(nullchk)
