# Deliverable 5: cross-device diagnostics. Heatmap data, lagged cross-correlation, simultaneous tails,
# with PERMUTATION nulls that keep each device's own temporal structure and missingness:
# each device series is circularly shifted by an independent random offset (this breaks cross-device
# alignment but nothing else) -> exact max-T family-wise adjusted p-values. A circular block bootstrap
# (block 300 s, same blocks for all devices, preserves cross-device alignment) gives confidence intervals.
# Disclosed assumption: circular wrap-around; shifts are uniform on 1..T-1; seeds fixed.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
dd <- read_dense(); X <- dd$X; ids <- dd$ids; Tn <- nrow(X); nd <- ncol(X)
M <- !is.na(X); Z0 <- ifelse(M, z_of(X), 0)       # Z0 holds 0 ONLY where M is FALSE and is only ever multiplied by M
pairs <- which(upper.tri(diag(nd)), arr.ind = TRUE); npair <- nrow(pairs)
pearson_pc <- function(Z0, M) {                    # pairwise-complete Pearson matrix from masked sums
  Mn <- M * 1; n <- crossprod(Mn)
  Sx <- crossprod(Z0, Mn); Sxx <- crossprod(Z0^2, Mn); Sxy <- crossprod(Z0)
  cxy <- Sxy - Sx * t(Sx) / n
  vx <- Sxx - Sx^2 / n; vy <- t(vx)
  r <- cxy / sqrt(vx * vy); list(r = r, n = n)
}
shift_idx <- function(s) { ix <- outer(seq_len(Tn), s, function(i, sh) ((i - 1 - sh) %% Tn) + 1); ix }
gather <- function(A, ix) A[cbind(as.vector(ix), rep(seq_len(ncol(A)), each = nrow(A)))]
obs <- pearson_pc(Z0, M); R <- obs$r; N <- obs$n
rv <- R[pairs]; nv <- N[pairs]
fz <- atanh(rv) * sqrt(nv - 3); p_fisher <- 2 * pnorm(-abs(fz))
# ---- permutation null (circular shifts) for the global statistics, B = 2000
B <- 1000L; set.seed(seed_for("crossdev-shift"))
st_obs <- c(max_abs_r = max(abs(rv)), mean_r2 = mean(rv^2), mean_r = mean(rv))
st_null <- matrix(NA_real_, B, 3)
for (b in seq_len(B)) {
  s <- sample.int(Tn - 1, nd, TRUE); ix <- shift_idx(s)
  Zs <- matrix(gather(Z0, ix), Tn, nd); Ms <- matrix(gather(M * 1, ix), Tn, nd) > 0
  rb <- pearson_pc(Zs, Ms)$r[pairs]; st_null[b, ] <- c(max(abs(rb)), mean(rb^2), mean(rb))
}
pg <- function(o, nl, two = FALSE) (1 + sum(if (two) abs(nl) >= abs(o) else nl >= o)) / (B + 1)
glob <- data.frame(statistic = c("max_abs_pairwise_r", "mean_squared_r", "mean_r"),
  observed = st_obs, null_mean = colMeans(st_null), null_q975 = apply(st_null, 2, quantile, .975),
  p_perm = c(pg(st_obs[1], st_null[, 1]), pg(st_obs[2], st_null[, 2]), pg(st_obs[3], st_null[, 3], TRUE)))
# max-T adjusted p per pair at lag 0 (Pearson, shift null)
maxnull <- st_null[, 1]
p_maxT0 <- sapply(abs(rv), function(o) (1 + sum(maxnull >= o)) / (B + 1))
# ---- block bootstrap CI (circular, block 300, same blocks for all devices), B = 500
set.seed(seed_for("crossdev-block")); Bb <- 500L; bl <- 300L; nblk <- ceiling(Tn / bl)
bb <- t(replicate(Bb, { st <- sample.int(Tn, nblk, TRUE); idx <- (((as.vector(outer(0:(bl - 1), st, "+")) - 1) %% Tn) + 1)[1:Tn]
  rb <- pearson_pc(Z0[idx, ], M[idx, ])$r[pairs]; c(mean(rb), max(abs(rb)), mean(rb^2)) }))
ci <- data.frame(statistic = c("mean_r", "max_abs_r", "mean_r2"), boot_lo = apply(bb, 2, quantile, .025), boot_hi = apply(bb, 2, quantile, .975))
# ---- lagged cross-correlation via FFT (reference-scaled products; z known under H0: mean 0, var 1)
FZ <- apply(Z0, 2, fft); FM <- apply(M * 1, 2, fft)
Lmax <- 60L; lags <- -Lmax:Lmax
TT <- matrix(NA_real_, Tn, npair)              # t-statistic for every circular lag l = 0..T-1
for (p in seq_len(npair)) { i <- pairs[p, 1]; j <- pairs[p, 2]
  num <- Re(fft(Conj(FZ[, i]) * FZ[, j], inverse = TRUE)) / Tn      # sum_t z_i[t] z_j[t+l]
  nn <- Re(fft(Conj(FM[, i]) * FM[, j], inverse = TRUE)) / Tn
  nn <- round(nn); TT[, p] <- ifelse(nn > 0, num / sqrt(pmax(nn, 1)), NA_real_) }
lag_cols <- ((lags) %% Tn) + 1L
obsT <- TT[lag_cols, , drop = FALSE]                  # 121 x npair
obs_max_pair <- apply(abs(obsT), 2, max); obs_lag <- lags[apply(abs(obsT), 2, which.max)]
obs_max_all <- max(obs_max_pair)
set.seed(seed_for("crossdev-lag")); Bl <- 5000L
nullmax <- numeric(Bl); nullmax0 <- numeric(Bl)
off_p <- (seq_len(npair) - 1) * Tn
for (b in seq_len(Bl)) {
  s <- sample.int(Tn - 1, nd, TRUE); d <- s[pairs[, 2]] - s[pairs[, 1]]
  ix <- ((outer(lags, d, "+")) %% Tn) + 1L + rep(off_p, each = length(lags))
  v <- abs(TT[ix]); nullmax[b] <- max(v, na.rm = TRUE)
  nullmax0[b] <- max(v[Lmax + 1 + (0:(npair - 1)) * length(lags)], na.rm = TRUE)
}
p_lag_adj <- sapply(obs_max_pair, function(o) (1 + sum(nullmax >= o)) / (Bl + 1))
lag0 <- TT[1, ]; p_lag0_adj <- sapply(abs(lag0), function(o) (1 + sum(nullmax0 >= o)) / (Bl + 1))
# ---- simultaneous tails: |X-100| >= 14 for both devices at the same second
pt <- sum(binom_pmf()[abs(0:200 - 100) >= 14])
E0 <- ifelse(M & abs(X - 100) >= 14, 1, 0); E0[!M] <- 0
tail_stat <- function(E0, M) { Mn <- M * 1; n <- crossprod(Mn); S <- crossprod(E0); z <- (S - n * pt^2) / sqrt(n * pt^2 * (1 - pt^2)); list(S = S, n = n, z = z) }
to <- tail_stat(E0, M); tz <- to$z[pairs]; tS <- to$S[pairs]; texp <- (to$n * pt^2)[pairs]
Kt <- rowSums(E0); kk <- rowSums(M)
kstats <- function(K, k) c(var_ratio = sum((K - k * pt)^2) / sum(k * pt * (1 - pt)),
  ge4 = sum(K >= 4), ge5 = sum(K >= 5), ge6 = sum(K >= 6))
kobs <- kstats(Kt, kk)
exp_ge <- sapply(c(4, 5, 6), function(m) sum(pbinom(m - 1, kk, pt, lower.tail = FALSE)))
set.seed(seed_for("crossdev-tail")); Bt <- 1000L
tnull <- matrix(NA_real_, Bt, 5)
for (b in seq_len(Bt)) {
  s <- sample.int(Tn - 1, nd, TRUE); ix <- shift_idx(s)
  Es <- matrix(gather(E0, ix), Tn, nd); Ms <- matrix(gather(M * 1, ix), Tn, nd) > 0
  tb <- tail_stat(Es, Ms)$z[pairs]; kb <- kstats(rowSums(Es), rowSums(Ms))   # note: shifting breaks alignment of K but keeps marginals
  tnull[b, ] <- c(max(abs(tb)), kb["var_ratio"], kb["ge4"], kb["ge5"], kb["ge6"])
}
p_tail_adj <- sapply(abs(tz), function(o) (1 + sum(tnull[, 1] >= o)) / (Bt + 1))
tail_glob <- data.frame(statistic = c("var_ratio_of_K_(devices_in_tail_per_second)", "seconds_with_K>=4", "seconds_with_K>=5", "seconds_with_K>=6"),
  observed = kobs, expected_independent = c(1, exp_ge), null_mean = colMeans(tnull[, 2:5]),
  p_perm_two_sided = c(mean(abs(tnull[, 2] - 1) >= abs(kobs[1] - 1)), sapply(1:3, function(q) mean(abs(tnull[, 2 + q] - mean(tnull[, 2 + q])) >= abs(kobs[1 + q] - mean(tnull[, 2 + q]))))))
tail_glob$p_perm_two_sided <- (tail_glob$p_perm_two_sided * Bt + 1) / (Bt + 1)
# ---- pair table
PT <- data.frame(dev_i = ids[pairs[, 1]], dev_j = ids[pairs[, 2]], n_pair = nv, r = rv, p_fisher = p_fisher, q_BH_fisher = p.adjust(p_fisher, "BH"),
  p_maxT_perm_lag0_pearson = p_maxT0, ref_scaled_t_lag0 = lag0, p_maxT_perm_lag0_refscaled = p_lag0_adj,
  max_abs_t_over_lags_pm60 = obs_max_pair, lag_at_max_s = obs_lag, p_maxT_perm_lagged = p_lag_adj,
  tail_both_obs = tS, tail_both_expected = texp, tail_z = tz, p_maxT_perm_tail = p_tail_adj)
write_tsv_num(PT, "r_pair_crossdev.tsv"); write_tsv_num(glob, "r_crossdev_global.tsv"); write_tsv_num(ci, "r_crossdev_bootstrap_ci.tsv")
write_tsv_num(tail_glob, "r_crossdev_tail_global.tsv")
lagsum <- data.frame(observed_max_abs_t_all_pairs_lags = obs_max_all, null_median = median(nullmax), null_q95 = quantile(nullmax, .95),
  p_global_perm = (1 + sum(nullmax >= obs_max_all)) / (Bl + 1), lags = "-60..60 s", pairs = npair, shifts = Bl)
write_tsv_num(lagsum, "r_crossdev_lag_global.tsv")
# lag profile (for ACF-like figure): mean |t| per lag across pairs vs null expectation sqrt(2/pi)
write_tsv_num(data.frame(lag = lags, mean_abs_t = rowMeans(abs(obsT), na.rm = TRUE), mean_t2 = rowMeans(obsT^2, na.rm = TRUE)), "r_crossdev_lag_profile.tsv")
cat("crossdev done\n"); print(glob); print(ci); print(lagsum); print(tail_glob)
print(head(PT[order(PT$p_maxT_perm_lagged), c("dev_i", "dev_j", "r", "p_fisher", "q_BH_fisher", "p_maxT_perm_lag0_pearson", "max_abs_t_over_lags_pm60", "lag_at_max_s", "p_maxT_perm_lagged", "tail_z", "p_maxT_perm_tail")], 6))
