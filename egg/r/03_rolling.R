# Deliverable 4: rolling mean / variance / entropy at 60, 300, 1800 s, QUALIFIED windows only.
# Windows are non-overlapping (step = window length, so windows are separate samples) and a
# per-device window is qualified only if all of its seconds are observed. Effective sample size of a
# per-device window = w (cells assumed independent; see ACF results). Nulls: simulated Binomial(200,.5)
# windows of the same size (B=20000, fixed seeds); entropy is plug-in vs Miller-Madow vs theory.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
dd <- read_dense(); X <- dd$X; ids <- dd$ids; Tn <- nrow(X); nd <- ncol(X)
Hth <- H_theory(); Hmth <- Hmin_theory(); pmf <- binom_pmf()
nz <- network_Z(X)
dev_rows <- list(); glob_rows <- list(); net_rows <- list(); series <- list()
for (w in EGG$windows) {
  nb <- Tn %/% w
  set.seed(seed_for(paste0("rollnull", w)))
  Bn <- 20000L
  sim <- matrix(rbinom(Bn * w, 200, 0.5), nrow = w)                 # columns = null windows
  sv <- apply(sim, 2, var)
  sH <- apply(sim, 2, function(c) { t <- tabulate(c + 1L, 201); c(H_plugin(t), H_mm(t), Hmin_plugin(t)) })
  null <- list(var_lo = quantile(sv, c(.005, .995)), Hp = sH[1, ], Hm = sH[2, ], Hmin = sH[3, ])
  null_sum_p <- function(S) { pl <- pbinom(S, 200 * w, .5); ph <- pbinom(S - 1, 200 * w, .5, lower.tail = FALSE); pmin(1, 2 * pmin(pl, ph)) }
  allq <- list()
  for (j in seq_len(nd)) {
    M <- matrix(X[1:(nb * w), j], nrow = w)          # w x nb
    q <- colSums(is.na(M)) == 0
    Mq <- M[, q, drop = FALSE]; nq <- ncol(Mq)
    if (nq == 0) next
    S <- colSums(Mq); vv <- apply(Mq, 2, var)
    H <- apply(Mq, 2, function(c) { t <- tabulate(c + 1L, 201); c(H_plugin(t), H_mm(t), Hmin_plugin(t)) })
    pmean <- null_sum_p(S)
    pvar <- vapply(vv, function(v) 2 * min(mean(sv <= v), mean(sv >= v)) + 0, 0)
    pvar <- pmax(pvar, 1 / Bn)
    pH <- vapply(H[1, ], function(h) 2 * min(mean(null$Hp <= h), mean(null$Hp >= h)), 0); pH <- pmax(pH, 1 / Bn)
    tail1 <- function(p) sum(p < 0.01)
    bt <- function(k, n) binom.test(k, n, 0.01)$p.value
    dev_rows[[length(dev_rows) + 1]] <- data.frame(window_s = w, device = ids[j], windows_total = nb, windows_qualified = nq,
      qualified_frac = nq / nb, eff_sample_size_per_window = w,
      mean_of_window_means = mean(S / w), var_of_window_means = var(S / w), expected_var_of_window_means = 50 / w,
      mean_window_var = mean(vv), expected_window_var = 50,
      n_p_mean_lt_0.01 = tail1(pmean), p_binom_mean = bt(tail1(pmean), nq),
      n_p_var_lt_0.01 = tail1(pvar), p_binom_var = bt(tail1(pvar), nq),
      mean_H_plugin = mean(H[1, ]), mean_H_mm = mean(H[2, ]), mean_Hmin = mean(H[3, ]),
      n_p_H_lt_0.01 = tail1(pH), p_binom_H = bt(tail1(pH), nq))
    allq[[j]] <- cbind(device = ids[j], H1 = H[1, ], H2 = H[2, ], H3 = H[3, ], pH = pH, pm = pmean, pv = pvar)
  }
  A <- as.data.frame(do.call(rbind, allq), stringsAsFactors = FALSE); for (c in c("H1", "H2", "H3", "pH", "pm", "pv")) A[[c]] <- as.numeric(A[[c]])
  glob_rows[[length(glob_rows) + 1]] <- data.frame(window_s = w, qualified_device_windows = nrow(A), eff_n_each = w,
    observed_mean_H_plugin = mean(A$H1), observed_mean_H_mm = mean(A$H2),
    null_mean_H_plugin = mean(null$Hp), null_mean_H_mm = mean(null$Hm), theory_H = Hth,
    plugin_bias_vs_theory = mean(null$Hp) - Hth, mm_bias_vs_theory = mean(null$Hm) - Hth,
    obs_mean_Hmin = mean(A$H3), null_mean_Hmin = mean(null$Hmin), theory_Hmin = Hmth,
    frac_pmean_lt_0.01 = mean(A$pm < 0.01), frac_pvar_lt_0.01 = mean(A$pv < 0.01), frac_pH_lt_0.01 = mean(A$pH < 0.01),
    min_pmean = min(A$pm), min_pvar = min(A$pv), min_pH = min(A$pH),
    bonferroni_min_pH = min(1, min(A$pH) * nrow(A)), bonferroni_min_pmean = min(1, min(A$pm) * nrow(A)),
    bonferroni_min_pvar = min(1, min(A$pv) * nrow(A)),
    n_BH_q_lt_0.05_H = sum(p.adjust(A$pH, "BH") < 0.05), n_BH_q_lt_0.05_mean = sum(p.adjust(A$pm, "BH") < 0.05),
    n_BH_q_lt_0.05_var = sum(p.adjust(A$pv, "BH") < 0.05))
  # ---- network-level pooled windows: pool every cell of devices complete in the window
  Zs <- nz$Z[1:(nb * w)]; kk <- nz$k[1:(nb * w)]
  cov_w <- numeric(nb); Hn <- matrix(NA_real_, nb, 3); nn <- integer(nb); zH <- numeric(nb); zwin <- numeric(nb)
  null_cache <- list()
  set.seed(seed_for(paste0("netnull", w)))
  for (b in seq_len(nb)) {
    rows <- ((b - 1) * w + 1):(b * w)
    blk <- X[rows, , drop = FALSE]
    cov_w[b] <- mean(!is.na(blk))
    comp <- colSums(is.na(blk)) == 0
    zwin[b] <- sum(Zs[rows]) / sqrt(w)
    if (sum(comp) >= 20) {
      cnt <- tabulate(as.vector(blk[, comp]) + 1L, 201); n <- sum(cnt); nn[b] <- n
      Hn[b, ] <- c(H_plugin(cnt), H_mm(cnt), Hmin_plugin(cnt))
      key <- as.character(n)
      if (is.null(null_cache[[key]])) { ns <- apply(rmultinom(400, n, pmf), 2, H_plugin); null_cache[[key]] <- c(mean(ns), sd(ns)) }
      zH[b] <- (Hn[b, 1] - null_cache[[key]][1]) / null_cache[[key]][2]
    } else zH[b] <- NA
  }
  qual <- !is.na(Hn[, 1])
  # exact-ish p for window network Z: sum of Z over window ~ N(0, w) if iid (approximation, stated)
  pzw <- 2 * pnorm(-abs(zwin))
  net_rows[[length(net_rows) + 1]] <- data.frame(window_s = w, windows_total = nb, windows_qualified_for_pooled_entropy = sum(qual),
    mean_window_coverage = mean(cov_w), min_window_coverage = min(cov_w),
    pooled_n_per_window_min = min(nn[qual]), pooled_n_per_window_max = max(nn[qual]),
    mean_H_plugin = mean(Hn[qual, 1]), mean_H_mm = mean(Hn[qual, 2]), theory_H = Hth, mean_Hmin = mean(Hn[qual, 3]), theory_Hmin = Hmth,
    mean_zH = mean(zH[qual]), sd_zH = sd(zH[qual]), frac_abs_zH_gt_2.576 = mean(abs(zH[qual]) > 2.576), expected_frac = 0.01,
    min_p_zH = min(2 * pnorm(-abs(zH[qual]))), bonferroni_min_p_zH = min(1, min(2 * pnorm(-abs(zH[qual]))) * sum(qual)),
    var_window_netZ = var(zwin), mean_window_netZ = mean(zwin), frac_abs_winZ_gt_2.576 = mean(abs(zwin) > 2.576),
    min_p_winZ = min(pzw), bonferroni_min_p_winZ = min(1, min(pzw) * nb))
  series[[length(series) + 1]] <- data.frame(window_s = w, window = seq_len(nb), t_start = dd$t[(seq_len(nb) - 1) * w + 1],
    coverage = cov_w, pooled_n = nn, H_plugin = Hn[, 1], H_mm = Hn[, 2], Hmin = Hn[, 3], zH = zH, window_netZ = zwin)
  # also dump Futhark-comparable rolling stats for parity (device j=1 and 33)
  if (w == 60) { M1 <- matrix(X[1:(nb * w), 1], nrow = w); write.table(data.frame(mean = colMeans(M1), var = apply(M1, 2, var)),
    file.path(D$out, "r_roll60_dev1.tsv"), sep = "\t", quote = FALSE, row.names = FALSE) }
}
dv <- do.call(rbind, dev_rows); gl <- do.call(rbind, glob_rows); nt <- do.call(rbind, net_rows); se <- do.call(rbind, series)
# multiplicity across the 25 x 3 device/window tests for each of three families
for (f in c("p_binom_mean", "p_binom_var", "p_binom_H")) dv[[paste0(f, "_BH")]] <- p.adjust(dv[[f]], "BH")
# all 225 device x window x metric tests as one family (the conservative reading)
allp <- p.adjust(c(dv$p_binom_mean, dv$p_binom_var, dv$p_binom_H), "BH"); n <- nrow(dv)
dv$p_binom_mean_BHall <- allp[1:n]; dv$p_binom_var_BHall <- allp[n + 1:n]; dv$p_binom_H_BHall <- allp[2 * n + 1:n]
write_tsv_num(dv, "r_rolling_device.tsv"); write_tsv_num(gl, "r_rolling_global.tsv"); write_tsv_num(nt, "r_rolling_network.tsv")
write_tsv_num(se, "r_rolling_network_series.tsv", sig = 6)
cat("rolling done\n"); print(t(gl)); print(t(nt))
print(dv[order(dv$p_binom_H)[1:5], c("window_s", "device", "windows_qualified", "n_p_H_lt_0.01", "p_binom_H", "p_binom_H_BH", "p_binom_H_BHall")])
