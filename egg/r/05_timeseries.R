# Deliverable 6: ACF/PACF/Ljung-Box, FFT periodogram, Welch PSD, multiplicity-aware peak detection.
# Assumptions (stated, not hidden):
#  * ACF/PACF for devices with missing cells use R's na.pass (products over observed pairs only). Gaps are NOT
#    filled. Ljung-Box uses n = number of observed cells: approximate for those devices.
#  * Periodograms need an evenly spaced complete series. Done for network Z and for complete devices only.
#    Devices with gaps are listed as not analysed spectrally.
#  * Periodogram ordinates of iid N(0,1) are Exp(1). Network Z is only approximately Gaussian, so the analytic
#    p-values are cross-checked against exact-binomial null simulations.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
dd <- read_dense(); X <- dd$X; ids <- dd$ids; Tn <- nrow(X); nd <- ncol(X)
ns <- read.delim(file.path(D$out, "r", "network_z_series.tsv")); stopifnot(!anyNA(ns$Z), nrow(ns) == Tn)
Zn <- ns$Z; kt <- ns$k; zdev <- z_of(X)
L <- 60L
lb <- function(r, n, h) { Q <- n * (n + 2) * sum(r[1:h]^2 / (n - 1:h)); c(Q = Q, p = pchisq(Q, h, lower.tail = FALSE)) }
one <- function(x) { n <- sum(!is.na(x)); a <- acf(x, lag.max = L, na.action = na.pass, plot = FALSE)$acf[-1, 1, 1]
  pa <- pacf(x, lag.max = L, na.action = na.pass, plot = FALSE)$acf[, 1, 1]; l10 <- lb(a, n, 10); l60 <- lb(a, n, 60)
  list(n = n, acf = a, pacf = pa, lb10 = l10, lb60 = l60, out = sum(abs(a) > 1.96 / sqrt(n)), band = 1.96 / sqrt(n)) }
net <- one(Zn)
write_tsv_num(data.frame(lag = 1:L, acf = net$acf, pacf = net$pacf, band95 = net$band), "r_acf_network.tsv")
dv <- lapply(seq_len(nd), function(i) one(zdev[, i]))
acf_dev <- data.frame(device = ids, n = sapply(dv, `[[`, "n"), acf_lag1 = sapply(dv, function(o) o$acf[1]),
  max_abs_acf_lags1_60 = sapply(dv, function(o) max(abs(o$acf))), lags_outside_95band_of_60 = sapply(dv, `[[`, "out"),
  LB10_Q = sapply(dv, function(o) o$lb10["Q"]), LB10_p = sapply(dv, function(o) o$lb10["p"]),
  LB60_Q = sapply(dv, function(o) o$lb60["Q"]), LB60_p = sapply(dv, function(o) o$lb60["p"]))
net_row <- data.frame(device = "network", n = net$n, acf_lag1 = net$acf[1], max_abs_acf_lags1_60 = max(abs(net$acf)), lags_outside_95band_of_60 = net$out,
  LB10_Q = net$lb10["Q"], LB10_p = net$lb10["p"], LB60_Q = net$lb60["Q"], LB60_p = net$lb60["p"])
acf_all <- rbind(net_row, acf_dev)
acf_all$LB10_p_BH <- p.adjust(acf_all$LB10_p, "BH"); acf_all$LB60_p_BH <- p.adjust(acf_all$LB60_p, "BH")
both <- p.adjust(c(acf_all$LB10_p, acf_all$LB60_p), "BH"); acf_all$LB10_p_BH_both <- both[seq_len(nrow(acf_all))]; acf_all$LB60_p_BH_both <- both[nrow(acf_all) + seq_len(nrow(acf_all))]
write_tsv_num(acf_all, "r_acf_summary.tsv")
# POST-HOC follow-up (not predeclared, not a holdout): for any series flagged at BH < 0.05, repeat Ljung-Box lag 10 on quarters of the day.
flag <- acf_all$device[which(acf_all$LB10_p_BH < .05 | acf_all$LB60_p_BH < .05)]
fu <- do.call(rbind, lapply(flag, function(d) { x <- if (d == "network") Zn else zdev[, which(ids == d)]; q <- split(seq_along(x), cut(seq_along(x), 4, labels = FALSE))
  do.call(rbind, lapply(seq_along(q), function(i) { xx <- x[q[[i]]]; n <- sum(!is.na(xx)); a <- acf(xx, 10, na.action = na.pass, plot = FALSE)$acf[-1, 1, 1]; l <- lb(a, n, 10)
    data.frame(series = d, quarter = i, n = n, acf_lag1 = a[1], LB10_Q = l["Q"], LB10_p = l["p"]) })) }))
if (!is.null(fu)) write_tsv_num(fu, "r_acf_followup_quarters.tsv")
# ---- periodogram, network Z. I_k = |DFT|^2 / n, k = 1..n/2-1; null Exp(1)
per <- function(x) { n <- length(x); f <- fft(x); k <- 1:(n / 2 - 1); Mod(f[k + 1])^2 / n }
I <- per(Zn); m <- length(I); k <- seq_len(m)
pk <- exp(-I); p_bonf <- pmin(1, m * pk); q_bh <- p.adjust(pk, "BH")
g <- max(I) / sum(I); p_fisher <- min(1, m * (1 - g)^(m - 1))     # leading term of Fisher's exact formula
set.seed(seed_for("spectral-null")); Bs <- 500L
sim_stats <- t(sapply(seq_len(Bs), function(b) { zs <- (rbinom(Tn, 200L * kt, 0.5) - 100 * kt) / sqrt(50 * kt); Is <- per(zs); c(max(Is), max(Is) / sum(Is)) }))
p_max_sim <- (1 + sum(sim_stats[, 1] >= max(I))) / (Bs + 1)
o <- order(I, decreasing = TRUE)[1:10]
peaks <- data.frame(rank = 1:10, k = o, freq_hz = o / Tn, period_s = Tn / o, ordinate = I[o], p_raw = pk[o], p_bonferroni = p_bonf[o], q_BH = q_bh[o])
write_tsv_num(peaks, "r_periodogram_peaks.tsv")
spec_sum <- data.frame(series = "network_Z", n = Tn, frequencies = m, mean_ordinate = mean(I), max_ordinate = max(I), fisher_g = g, p_fisher_g = p_fisher,
  p_max_ordinate_sim_exact_binomial = p_max_sim, null_sim_max_median = median(sim_stats[, 1]), null_sim_max_q95 = quantile(sim_stats[, 1], .95),
  n_bonferroni_hits = sum(p_bonf < .05), n_BH_hits = sum(q_bh < .05), sim_B = Bs)
# complete devices
cdev <- which(colSums(is.na(X)) == 0); dsp <- do.call(rbind, lapply(cdev, function(i) { Id <- per(zdev[, i]); gg <- max(Id) / sum(Id); mm <- length(Id)
  data.frame(series = paste0("device_", ids[i]), n = Tn, frequencies = mm, mean_ordinate = mean(Id), max_ordinate = max(Id), fisher_g = gg,
    p_fisher_g = min(1, mm * (1 - gg)^(mm - 1)), p_max_ordinate_sim_exact_binomial = NA, null_sim_max_median = NA, null_sim_max_q95 = NA,
    n_bonferroni_hits = sum(pmin(1, mm * exp(-Id)) < .05), n_BH_hits = sum(p.adjust(exp(-Id), "BH") < .05), sim_B = NA) }))
dsp$p_fisher_g_BH <- p.adjust(dsp$p_fisher_g, "BH"); spec_sum$p_fisher_g_BH <- NA
write_tsv_num(rbind(spec_sum, dsp), "r_periodogram_summary.tsv")
write_tsv_num(data.frame(device = ids[setdiff(seq_len(nd), cdev)], reason = "has missing cells; evenly spaced series needed; not analysed spectrally"), "r_periodogram_not_analysed.tsv")
# ---- Welch (own implementation; Hann periodic window, 4096 s segments, 50% overlap, mean NOT removed since E[Z]=0 under H0)
welch <- function(x, nseg = 4096L, step = 2048L) { w <- 0.5 - 0.5 * cos(2 * pi * (0:(nseg - 1)) / nseg); U <- sum(w^2)
  st <- seq(1, length(x) - nseg + 1, by = step); P <- rowMeans(sapply(st, function(s) Mod(fft(x[s:(s + nseg - 1)] * w))^2 / U)[1:(nseg / 2 + 1), , drop = FALSE])
  list(f = (0:(nseg / 2)) / nseg, P = P, K = length(st)) }
W <- welch(Zn)
set.seed(seed_for("welch-null")); Bw <- 1000L
wmax <- sapply(seq_len(Bw), function(b) { zs <- (rbinom(Tn, 200L * kt, 0.5) - 100 * kt) / sqrt(50 * kt); max(welch(zs)$P[2:2048]) })
mx <- max(W$P[2:2048]); fm <- W$f[1 + which.max(W$P[2:2048])]
# per-bin pointwise null mean/sd from the same simulations is skipped; empirical max-null calibrates the whole spectrum
wo <- order(W$P[2:2048], decreasing = TRUE)[1:5] + 1
wpeaks <- data.frame(rank = 1:5, freq_hz = W$f[wo], period_s = 1 / W$f[wo], psd = W$P[wo], p_max_null_sim = sapply(W$P[wo], function(v) (1 + sum(wmax >= v)) / (Bw + 1)))
write_tsv_num(data.frame(freq_hz = W$f, psd = W$P), "r_welch_psd.tsv"); write_tsv_num(wpeaks, "r_welch_peaks.tsv")
write_tsv_num(data.frame(segments = W$K, mean_psd_excl_dc = mean(W$P[-1]), expected_white = 1, max_psd = mx, null_max_median = median(wmax),
  null_max_q95 = quantile(wmax, .95), p_max_global = (1 + sum(wmax >= mx)) / (Bw + 1), sim_B = Bw), "r_welch_summary.tsv")
cat("timeseries done\n"); print(acf_all[1:4, ]); print(peaks[1:4, ]); print(spec_sum); print(read.delim(file.path(D$res, "r_welch_summary.tsv"))); print(wpeaks[1:3, ])
print(head(dsp[order(dsp$p_fisher_g), c("series", "fisher_g", "p_fisher_g", "p_fisher_g_BH")], 3))
print(acf_all[order(acf_all$LB60_p)[1:4], c("device", "LB10_p", "LB60_p", "LB60_p_BH")])
