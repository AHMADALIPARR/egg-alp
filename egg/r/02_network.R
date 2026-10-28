# Deliverable 3: network-Z series with coverage, plus the explicit covariance-calibrated variant.
# Under the independent-device null the sum of the |V_t| observed counts at second t is exactly
# Binomial(200*|V_t|, 1/2), so every Z[t] has an EXACT two-sided p-value. Independence is tested
# separately (04_crossdev.R). Calibrated variant: Zc[t] = Z[t] / sqrt( (1/|V_t|) sum_{i,j in V_t} R_ij ),
# R = pairwise-complete empirical correlation matrix (estimated from the same data: a calibration,
# not an independent test). Block bootstrap (circular, block 300 s, B=1000, fixed seed) gives CIs.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
dd <- read_dense(); X <- dd$X; Tn <- nrow(X); nd <- ncol(X)
nz <- network_Z(X); Z <- nz$Z; k <- nz$k
stopifnot(all(k > 0))   # contract: |V_t| > 0 for every second here; the code would return NA otherwise
S <- rowSums(X, na.rm = TRUE)
# exact two-sided p (mid-p not used; doubled smaller tail, capped at 1)
plow <- pbinom(S, 200 * k, 0.5); phigh <- pbinom(S - 1, 200 * k, 0.5, lower.tail = FALSE)
pz <- pmin(1, 2 * pmin(plow, phigh))
# pairwise-complete correlation matrix (reference implementation)
Rm <- cor(X, use = "pairwise.complete.obs")
mask_key <- apply(!is.na(X), 1, function(r) paste(as.integer(r), collapse = ""))
uk <- unique(mask_key); vt <- numeric(Tn)
for (key in uk) { idx <- which(mask_key == key); m <- utf8ToInt(key) == 49L
  vt[idx] <- sum(Rm[m, m]) / sum(m) }
Zc <- Z / sqrt(vt)
# summaries
# Discrete exact p-values are NOT uniform (conservative), so a KS test on them is meaningless.
# Use the randomized probability-integral transform u = F(S-1) + U*pmf(S), exactly Uniform(0,1) under H0.
set.seed(seed_for("netz-pit")); u_pit <- pbinom(S - 1, 200 * k, 0.5) + runif(Tn) * dbinom(S, 200 * k, 0.5)
ksz <- ks.test(u_pit, "punif")
exp_gt3 <- sum(2 * pnorm(-3) * rep(1, Tn)); obs_gt3 <- sum(abs(Z) >= 3)
exp_gt2 <- sum(2 * pnorm(-2)); obs_gt2 <- sum(abs(Z) >= 2)
# exact expected counts of |Z|>=c using exact Binomial per k
exact_exp <- function(cc) sum(sapply(unique(k), function(kk) { s <- 0:(200 * kk); zz <- (s - 100 * kk) / sqrt(50 * kk)
  sum(dbinom(s[abs(zz) >= cc], 200 * kk, 0.5)) * sum(k == kk) }))
e2 <- exact_exp(2); e3 <- exact_exp(3)
ac <- function(x, lag) { x <- x - mean(x); sum(x[1:(length(x) - lag)] * x[(1 + lag):length(x)]) / sum(x^2) }
walk_end <- sum(Z) / sqrt(Tn)       # N(0,1) if Z iid N(0,1)
# circular block bootstrap of var(Z) and mean(Z)
set.seed(seed_for("netz-bootstrap")); B <- 1000L; bl <- 300L; nblk <- ceiling(Tn / bl)
bs <- t(replicate(B, { st <- sample.int(Tn, nblk, TRUE); idx <- as.vector(outer(0:(bl - 1), st, "+")); idx <- ((idx - 1) %% Tn) + 1; zz <- Z[idx[1:Tn]]
  c(mean(zz), var(zz)) }))
off <- Rm[upper.tri(Rm)]
smry <- data.frame(
  metric = c("seconds", "mean_valid_devices", "min_valid_devices", "seconds_with_zero_devices",
    "mean_Z", "var_Z", "var_Z_ci_lo_blockboot", "var_Z_ci_hi_blockboot", "mean_Z_ci_lo_blockboot", "mean_Z_ci_hi_blockboot",
    "sd_Z", "lag1_acf_Z", "random_walk_end_over_sqrtT", "randomized_PIT_uniform_KS_p",
    "obs_abs_Z_ge_2", "exp_abs_Z_ge_2_exact", "poisson_two_sided_p_ge_2", "obs_abs_Z_ge_3", "exp_abs_Z_ge_3_exact", "poisson_two_sided_p_ge_3",
    "min_exact_p", "min_exact_p_bonferroni", "n_BH_q_lt_0.05", "mean_offdiag_corr", "max_abs_offdiag_corr",
    "mean_Zc", "var_Zc", "lag1_acf_Zc", "mean_calibration_var_factor"),
  value = c(Tn, mean(k), min(k), sum(k == 0), mean(Z), var(Z), quantile(bs[, 2], .025), quantile(bs[, 2], .975),
    quantile(bs[, 1], .025), quantile(bs[, 1], .975), sd(Z), ac(Z, 1), walk_end, ksz$p.value,
    obs_gt2, e2, poisson.test(obs_gt2, 1, e2)$p.value, obs_gt3, e3, poisson.test(obs_gt3, 1, e3)$p.value, min(pz), min(1, min(pz) * Tn), sum(p.adjust(pz, "BH") < 0.05), mean(off), max(abs(off)),
    mean(Zc), var(Zc), ac(Zc, 1), mean(vt)))
write_tsv_num(smry, "r_network_z_summary.tsv", sig = 9)
# minute-level series for plots/commit (never imputed: minute mean of Z over all seconds; k mean = coverage)
mi <- (seq_len(Tn) - 1) %/% 60
mn <- data.frame(minute = unique(mi), t_start = dd$t[!duplicated(mi)],
  Z_mean_times_sqrt60 = as.numeric(tapply(Z, mi, sum)) / sqrt(60),
  Zc_sum_over_sqrt60 = as.numeric(tapply(Zc, mi, sum)) / sqrt(60),
  valid_devices_mean = as.numeric(tapply(k, mi, mean)))
write_tsv_num(mn, "r_network_z_minute.tsv", sig = 6)
# full second-level series stays out of git
dir.create(file.path(D$out, "r"), showWarnings = FALSE)
write.table(data.frame(t = dd$t, k = k, Z = signif(Z, 12), p_exact = signif(pz, 8), Zc = signif(Zc, 12)),
  file.path(D$out, "r", "network_z_series.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
# cumulative walk for plot
write.table(data.frame(t = dd$t, cumZ_over_sqrtN = cumsum(Z) / sqrt(seq_len(Tn))), file.path(D$out, "r", "network_z_walk.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
# R correlation matrix for heatmap and parity
write.table(round(Rm, 12), file.path(D$res, "r_corr_matrix.tsv"), sep = "\t", quote = FALSE, col.names = NA)
cat("network Z done\n"); print(smry)
