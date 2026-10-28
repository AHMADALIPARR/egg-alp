# One-line-per-test summary of the real-data results, computed from the result files. Writes results/headline.tsv.
# verdict: "survives correction" only when the corrected p/q is below 0.05. Nothing here is confirmed: there is no holdout date.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
rd <- function(f) read.delim(file.path(D$res, f), check.names = FALSE)
kv <- function(f) { x <- rd(f); setNames(x$value, x$metric) }
rows <- list(); add <- function(test, family, stat, p_raw, p_adj, how) rows[[length(rows) + 1]] <<- data.frame(test = test, family = family, statistic = stat, p_raw = p_raw, p_corrected = p_adj, correction = how,
  verdict = ifelse(is.na(p_adj), "n/a", ifelse(p_adj < 0.05, "survives correction (exploratory)", "null")), stringsAsFactors = FALSE)
g <- rd("r_pooled_gof.tsv"); ds <- rd("r_device_summary.tsv"); nz <- kv("r_network_z_summary.tsv")
add("Pooled Pearson GOF vs Binomial(200,.5)", "device GOF", g$pearson_X2, g$pearson_p, g$pearson_p, "single test")
add("Pooled likelihood-ratio GOF", "device GOF", g$lr_G2, g$lr_p, g$lr_p, "single test")
for (c in c("pearson", "lr")) { col <- paste0(c, "_p"); i <- which.min(ds[[col]]); add(sprintf("Per-device %s GOF, smallest p (device %s)", c, ds$device[i]), "25 devices", ds[[paste0(c, "_G2")]][i] %||% ds$pearson_X2[i], ds[[col]][i], ds[[paste0(col, "_holm")]][i], "Holm over 25") }
i <- which.min(ds$p_mean); add(sprintf("Per-device mean vs 100, smallest p (device %s)", ds$device[i]), "25 devices", ds$z_mean[i], ds$p_mean[i], ds$p_mean_holm[i], "Holm over 25")
i <- which.min(ds$p_var);  add(sprintf("Per-device variance vs 50, smallest p (device %s)", ds$device[i]), "25 devices", ds$var_ratio_chi2[i], ds$p_var[i], ds$p_var_holm[i], "Holm over 25")
add("Network Z: variance of Z (expect 1)", "network Z", nz[["var_Z"]], NA, NA, "estimate with block-bootstrap CI only")
add("Network Z: seconds with |Z| >= 3 (observed vs exact expected)", "network Z", nz[["obs_abs_Z_ge_3"]], nz[["poisson_two_sided_p_ge_3"]], nz[["poisson_two_sided_p_ge_3"]], "single test")
add("Network Z: most extreme second", "network Z", NA, nz[["min_exact_p"]], nz[["min_exact_p_bonferroni"]], "Bonferroni over 86400 s")
rg <- rd("r_rolling_global.tsv"); rdv <- rd("r_rolling_device.tsv")
add("Rolling entropy/mean/variance per device, smallest corrected p", "225 rolling tests", NA, min(rdv$p_binom_H, rdv$p_binom_mean, rdv$p_binom_var, na.rm = TRUE),
    min(rdv$p_binom_H_BHall, rdv$p_binom_mean_BHall, rdv$p_binom_var_BHall, na.rm = TRUE), "BH over all rolling tests")
cg <- rd("r_crossdev_global.tsv"); add("Cross-device: largest |r|", "cross-device", cg$observed[1], cg$p_perm[1], cg$p_perm[1], "permutation, max statistic")
lg <- rd("r_crossdev_lag_global.tsv"); add("Cross-device: lagged cross-correlation, any pair, lag +/-60 s", "cross-device", lg[[1]], lg$p_global_perm, lg$p_global_perm, "permutation, max over pairs and lags")
tg <- rd("r_crossdev_tail_global.tsv"); add("Cross-device: variance ratio of devices-in-tail per second", "cross-device", tg$observed[1], tg$p_perm_two_sided[1], tg$p_perm_two_sided[1], "single test")
ac <- rd("r_acf_summary.tsv"); a0 <- ac[ac$device == "network", ]
add("Network Z: Ljung-Box, 10 lags", "serial correlation", a0$LB10_Q, a0$LB10_p, a0$LB10_p_BH_both, "BH over 52 tests")
ac2 <- ac[ac$device != "network", ]; i <- which.min(ac2$LB10_p_BH_both)
add(sprintf("Devices: Ljung-Box 10 lags, smallest (device %s)", ac2$device[i]), "serial correlation", ac2$LB10_Q[i], ac2$LB10_p[i], ac2$LB10_p_BH_both[i], "BH over 52 tests")
ps <- rd("r_periodogram_summary.tsv"); n0 <- ps[1, ]
add("Network Z periodogram: Fisher g", "periodicity", n0$fisher_g, n0$p_fisher_g, n0$p_fisher_g, "single test")
add("Network Z periodogram: highest peak (exact-binomial null sims)", "periodicity", n0$max_ordinate, n0$p_max_ordinate_sim_exact_binomial, n0$p_max_ordinate_sim_exact_binomial, "max statistic")
w <- rd("r_welch_summary.tsv"); add("Welch PSD: highest peak", "periodicity", w$max_psd, w$p_max_global, w$p_max_global, "max statistic, null sims")
cpf <- file.path(D$res, "r_changepoint_cusum_gain.tsv")
if (file.exists(cpf)) { cp <- rd("r_changepoint_cusum_gain.tsv"); i <- which.min(cp$p_cusum)
  add(sprintf("Change point (CUSUM), smallest p (series %s)", cp$series[i]), "26 series", cp$cusum_stat[i], cp$p_cusum[i], cp$q_cusum_BH[i], "BH over 26 (null sims keep the missing-cell mask)")
  i <- which.min(cp$p_gain); add(sprintf("Change point (best single split gain), smallest p (series %s)", cp$series[i]), "26 series", cp$best_split_gain[i], cp$p_gain[i], cp$q_gain_BH[i], "BH over 26") }
h <- do.call(rbind, rows); write_tsv_num(h, "headline.tsv")
cat(sprintf("headline: %d tests, %d survive correction (exploratory), %d null\n", nrow(h), sum(grepl("^survives", h$verdict)), sum(h$verdict == "null")))
