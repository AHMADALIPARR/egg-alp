# Deliverable 2: per-device count / coverage / moments / binomial goodness-of-fit.
# PREDECLARED (docs/EGG-001-ANALYSIS-PLAN.md): Pearson X^2 and likelihood-ratio G^2 against the exact
# Binomial(200,.5) pmf, expected-bin pooling so every pooled bin has expected count >= 5 (tails pooled);
# df = bins - 1 (no parameters fitted). Monte-Carlo p-values (B=4000, fixed seeds) check the chi-square
# approximation. Holm and BH across the 25 devices. Cells are treated as independent: see report caveats.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
dd <- read_dense(); X <- dd$X; ids <- dd$ids; Tn <- nrow(X)
pmf <- binom_pmf(); n_bins_full <- 201
pool_bins <- function(n, pmf, min_exp = 5) {
  # returns list(group = integer map 0..200 -> pooled bin index); pool low tail, then high tail, so each expected >= min_exp
  e <- n * pmf
  lo <- 1; acc <- 0
  while (lo <= 201 && acc < min_exp) { acc <- acc + e[lo]; lo <- lo + 1 }
  hi <- 201; acc <- 0
  while (hi >= 1 && acc < min_exp) { acc <- acc + e[hi]; hi <- hi - 1 }
  # bins: [1..lo-1] -> one pooled low bin; lo..hi singles; [hi+1..201] pooled high bin
  g <- integer(201)
  g[1:(lo - 1)] <- 1L
  mid <- lo:hi; g[mid] <- 1L + seq_along(mid)
  g[(hi + 1):201] <- max(g) + 1L
  g
}
res <- list(); qres <- list(); tailres <- list()
qs <- c(0.001, 0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99, 0.999)
Hth <- H_theory(); Hmth <- Hmin_theory()
for (j in seq_along(ids)) {
  x <- X[, j]; ok <- !is.na(x); xv <- x[ok]; n <- length(xv)
  cnt <- tabulate(xv + 1L, nbins = 201)
  g <- pool_bins(n, pmf); nb <- max(g)
  obs <- as.numeric(tapply(cnt, g, sum)); ex <- n * as.numeric(tapply(pmf, g, sum))
  X2 <- sum((obs - ex)^2 / ex)
  G2 <- 2 * sum(ifelse(obs > 0, obs * log(obs / ex), 0))
  df <- nb - 1
  # Monte-Carlo p (same pooled bins), fixed seed per device
  set.seed(seed_for(paste0("gof", ids[j])))
  B <- 4000L; pe <- ex / n
  sim <- rmultinom(B, n, pe)
  X2s <- colSums((sim - ex)^2 / ex)
  G2s <- 2 * colSums(ifelse(sim > 0, sim * log(sim / ex), 0))
  m <- mean(xv); v <- var(xv); sk <- mean((xv - m)^3) / mean((xv - m)^2)^1.5
  ku <- mean((xv - m)^4) / mean((xv - m)^2)^2 - 3
  zm <- (m - 100) / sqrt(50 / n)
  vr <- (n - 1) * v / 50; pv_var <- 2 * min(pchisq(vr, n - 1), pchisq(vr, n - 1, lower.tail = FALSE))
  Hp <- H_plugin(cnt); Hm <- H_mm(cnt)
  # min-entropy with parametric bootstrap CI (from the empirical distribution; B=1000)
  set.seed(seed_for(paste0("hmin", ids[j])))
  hb <- apply(rmultinom(1000, n, cnt / n), 2, function(c) -log2(max(c) / n))
  # null distribution of plug-in H and Hmin at this n (Binomial sim, B=1000)
  nsim <- rmultinom(1000, n, pmf)
  Hn <- apply(nsim, 2, H_plugin); Hmn <- apply(nsim, 2, function(c) -log2(max(c) / n))
  res[[j]] <- data.frame(device = ids[j], n_valid = n, n_missing = Tn - n, coverage = n / Tn,
    mean = m, var = v, sd = sqrt(v), skew = sk, excess_kurt = ku,
    z_mean = zm, p_mean = 2 * pnorm(-abs(zm)), var_ratio_chi2 = vr, p_var = pv_var,
    bins_pooled = nb, pearson_X2 = X2, pearson_df = df, pearson_p = pchisq(X2, df, lower.tail = FALSE),
    pearson_p_mc = (1 + sum(X2s >= X2)) / (B + 1),
    lr_G2 = G2, lr_p = pchisq(G2, df, lower.tail = FALSE), lr_p_mc = (1 + sum(G2s >= G2)) / (B + 1),
    H_plugin = Hp, H_miller_madow = Hm, H_theory = Hth, H_null_mean_plugin = mean(Hn),
    H_plugin_pnull = (1 + sum(Hn <= Hp)) / 1001,
    Hmin_plugin = -log2(max(cnt) / n), Hmin_boot_lo = quantile(hb, .025), Hmin_boot_hi = quantile(hb, .975),
    Hmin_theory = Hmth, Hmin_null_lo = quantile(Hmn, .025), Hmin_null_hi = quantile(Hmn, .975),
    row.names = NULL)
  # quantiles vs binomial
  q_obs <- as.numeric(quantile(xv, qs, type = 1)); q_th <- qbinom(qs, 200, 0.5)
  qres[[j]] <- data.frame(device = ids[j], q = qs, observed = q_obs, binomial = q_th)
  # tail counts: |z|>=2 and |z|>=3 style thresholds at integer cut points |X-100| >= 14, 21 (exact binomial tails)
  for (cut in c(14, 21)) {
    pt <- sum(pmf[abs(0:200 - 100) >= cut]); ob <- sum(abs(xv - 100) >= cut)
    bt <- binom.test(ob, n, pt)
    tailres[[length(tailres) + 1]] <- data.frame(device = ids[j], cut = cut, p_tail_exact = pt,
      expected = n * pt, observed = ob, ratio = ob / (n * pt), p_binom_test = bt$p.value)
  }
  # extremes
  tailres[[length(tailres) + 1]] <- data.frame(device = ids[j], cut = NA, p_tail_exact = NA,
      expected = NA, observed = NA, ratio = NA, p_binom_test = NA)
}
R <- do.call(rbind, res)
for (nm in c("p_mean", "p_var", "pearson_p", "pearson_p_mc", "lr_p", "lr_p_mc")) {
  R[[paste0(nm, "_holm")]] <- p.adjust(R[[nm]], "holm"); R[[paste0(nm, "_bh")]] <- p.adjust(R[[nm]], "BH")
}
Tt <- do.call(rbind, tailres); Tt <- Tt[!is.na(Tt$cut), ]
Tt$p_bh <- ave(Tt$p_binom_test, Tt$cut, FUN = function(p) p.adjust(p, "BH"))
Q <- do.call(rbind, qres)
# pooled (all devices)
allx <- as.vector(X); allx <- allx[!is.na(allx)]; cnt <- tabulate(allx + 1L, 201); n <- length(allx)
g <- pool_bins(n, pmf); obs <- as.numeric(tapply(cnt, g, sum)); ex <- n * as.numeric(tapply(pmf, g, sum))
pool <- data.frame(n = n, mean = mean(allx), var = var(allx), pearson_X2 = sum((obs - ex)^2 / ex), df = max(g) - 1,
  lr_G2 = 2 * sum(ifelse(obs > 0, obs * log(obs / ex), 0)), H_plugin = H_plugin(cnt), H_mm = H_mm(cnt), H_theory = Hth,
  Hmin = Hmin_plugin(cnt), Hmin_theory = Hmth)
pool$pearson_p <- pchisq(pool$pearson_X2, pool$df, lower.tail = FALSE); pool$lr_p <- pchisq(pool$lr_G2, pool$df, lower.tail = FALSE)
write_tsv_num(R, "r_device_summary.tsv"); write_tsv_num(Q, "r_device_quantiles.tsv"); write_tsv_num(Tt, "r_device_tails.tsv")
write_tsv_num(pool, "r_pooled_gof.tsv")
write_tsv_num(data.frame(k = 0:200, pmf = pmf), "r_binomial_pmf.tsv", sig = 15)
# per-device standardized deviation by count value (for figure): observed/expected - 1 pooled over all devices
write_tsv_num(data.frame(k = 0:200, observed = cnt, expected = n * pmf), "r_pooled_counts.tsv", sig = 12)
cat("device GOF done\n")
print(R[, c("device", "coverage", "mean", "var", "z_mean", "pearson_p", "lr_p", "pearson_p_mc", "H_plugin", "H_miller_madow", "Hmin_plugin")], digits = 4)
