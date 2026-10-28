# Cross-language parity: AWK vs Futhark vs R vs Octave on the real data. Prints PASS/FAIL per check and writes results/parity.tsv.
# Tolerances (stated): integers exact; floating-point relative 1e-9 unless the exchange file holds fewer digits
# (R result files keep 8 significant digits -> 1e-6; Octave files keep 12 digits -> 1e-9).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
rows <- list()
chk <- function(name, a, b, tol, what = "rel") {
  a <- as.numeric(a); b <- as.numeric(b)
  nan_ok <- identical(is.na(a), is.na(b)); ok_i <- !is.na(a) & !is.na(b)
  d <- if (what == "rel") abs(a[ok_i] - b[ok_i]) / pmax(1, abs(b[ok_i])) else abs(a[ok_i] - b[ok_i])
  md <- if (length(d)) max(d) else 0; pass <- nan_ok && md <= tol && length(a) == length(b)
  rows[[length(rows) + 1]] <<- data.frame(check = name, n_compared = sum(ok_i), na_pattern_equal = nan_ok, max_diff = md, tolerance = tol, status = if (pass) "PASS" else "FAIL")
}
rd <- function(f, ...) read.delim(f, na.strings = c("NA", ".nan", "NaN", ""), ...)
awkd <- rd(file.path(D$res, "awk_device.tsv")); fm <- rd(file.path(D$out, "fut/device_moments.tsv")); rs <- rd(file.path(D$res, "r_device_summary.tsv"))
dd <- read_dense(); X <- dd$X
# AWK vs Futhark (exact integers)
chk("AWK vs Futhark: per-device n_valid", awkd$n_valid, fm$n, 0, "abs")
chk("AWK vs Futhark: per-device sum", awkd$sum, fm$sum, 0, "abs")
chk("AWK vs Futhark: per-device sum of squares", awkd$sumsq, fm$sumsq, 0, "abs")
# AWK vs R
chk("AWK vs R: n_valid", awkd$n_valid, rs$n_valid, 0, "abs")
chk("AWK vs R: mean (sum/n)", awkd$sum / awkd$n_valid, rs$mean, 1e-6)
# Futhark vs R
rmean <- colMeans(X, na.rm = TRUE); rvar <- apply(X, 2, var, na.rm = TRUE)
chk("Futhark vs R (direct): device mean", fm$mean, rmean, 1e-12); chk("Futhark vs R (direct): device unbiased variance", fm$var_unbiased, rvar, 1e-9)
nz <- rd(file.path(D$out, "r/network_z_series.tsv")); fz <- rd(file.path(D$out, "fut/network_z.tsv"), header = FALSE)
chk("Futhark vs R: network Z per second (86,400)", fz[[1]], nz$Z, 1e-9); chk("Futhark vs R: |V_t| per second", fz[[2]], nz$k, 0, "abs")
fzc <- rd(file.path(D$out, "fut/network_z_calibrated.tsv"), header = FALSE); chk("Futhark vs R: calibrated network Z", fzc[[1]], nz$Zc, 1e-6)
fc <- as.matrix(rd(file.path(D$out, "fut/corr.tsv"), header = FALSE)); rc <- as.matrix(rd(file.path(D$res, "r_corr_matrix.tsv"), row.names = 1))
chk("Futhark vs R: pairwise-complete correlation matrix (625 cells)", as.vector(fc), as.vector(rc), 1e-9)
M <- !is.na(X); Rdirect <- cor(X, use = "pairwise.complete.obs"); chk("Futhark vs R (direct cor(use=pairwise)): correlation matrix", as.vector(fc), as.vector(Rdirect), 1e-9)
fv <- as.matrix(rd(file.path(D$out, "fut/roll60_var.tsv"), header = FALSE)); fmn <- as.matrix(rd(file.path(D$out, "fut/roll60_mean.tsv"), header = FALSE))
w <- 60; nw <- nrow(X) %/% w; rv <- matrix(NA_real_, nw, ncol(X)); rm_ <- rv
for (j in seq_len(nw)) { r <- ((j - 1) * w + 1):(j * w); full <- colSums(M[r, , drop = FALSE]) == w
  rv[j, full] <- apply(X[r, full, drop = FALSE], 2, var); rm_[j, full] <- colMeans(X[r, full, drop = FALSE]) }
fn <- as.matrix(rd(file.path(D$out, "fut/roll60_n.tsv"), header = FALSE)); chk("Futhark vs R: rolling-60 count of observed cells per window (1440x25)", fn, sapply(seq_len(ncol(X)), function(i) sapply(seq_len(nw), function(j) sum(M[((j - 1) * w + 1):(j * w), i]))), 0, "abs")
fv[fn != w] <- NA; fmn[fn != w] <- NA   # Futhark reports moments over observed cells; qualification (n == w) is applied here, as in R
chk("Futhark vs R: rolling-60 variance, fully observed windows only (qualified, NaN pattern)", fv, rv, 1e-9)
chk("Futhark vs R: rolling-60 mean, fully observed windows only", fmn, rm_, 1e-9)
sn <- rd(file.path(D$out, "fut/simnull_device.tsv")); chk("Futhark null simulation: n per device equals real observed count (same mask)", sn$n, awkd$n_valid, 0, "abs")
se <- sqrt(50 / sn$n); rows[[length(rows) + 1]] <- data.frame(check = "Futhark null simulation: device means within 4.5 SE of 100 (statistical sanity)", n_compared = nrow(sn), na_pattern_equal = TRUE,
  max_diff = max(abs(sn$mean - 100) / se), tolerance = 4.5, status = if (all(abs(sn$mean - 100) / se < 4.5)) "PASS" else "FAIL")
rows[[length(rows) + 1]] <- data.frame(check = "Futhark null simulation: device variances within 5% of 50 (statistical sanity)", n_compared = nrow(sn), na_pattern_equal = TRUE,
  max_diff = max(abs(sn$var / 50 - 1)), tolerance = 0.05, status = if (all(abs(sn$var / 50 - 1) < 0.05)) "PASS" else "FAIL")
# Octave vs R / Futhark
oc <- function(f, ...) { p <- file.path(D$out, "oct", f); if (!file.exists(p)) NULL else rd(p, header = FALSE, ...) }
om <- oc("oct_device_moments.tsv")
if (is.null(om)) rows[[length(rows) + 1]] <- data.frame(check = "Octave outputs", n_compared = 0, na_pattern_equal = NA, max_diff = NA, tolerance = NA, status = "UNAVAILABLE") else {
  chk("Octave vs AWK: n_valid", om[[1]], awkd$n_valid, 0, "abs"); chk("Octave vs Futhark: mean", om[[2]], fm$mean, 1e-9); chk("Octave vs Futhark: variance", om[[3]], fm$var_unbiased, 1e-9)
  ohead <- oc("oct_network_z_head.tsv"); chk("Octave vs R: network Z first 1000 s", ohead[[3]], nz$Z[1:1000], 1e-9); chk("Octave vs R: |V_t| first 1000 s", ohead[[2]], nz$k[1:1000], 0, "abs")
  os <- oc("oct_network_z_summary.tsv"); ok <- nz$k > 0; chk("Octave vs R: mean(Z)", os[[1]], mean(nz$Z[ok]), 1e-9, "abs"); chk("Octave vs R: var(Z)", os[[2]], var(nz$Z[ok]), 1e-9); chk("Octave vs R: count |Z|>=3", os[[3]], sum(abs(nz$Z[ok]) >= 3), 0, "abs")
  o5 <- as.matrix(oc("oct_corr5.tsv")); chk("Octave vs Futhark: correlation (5x5 block)", as.vector(o5), as.vector(fc[1:5, 1:5]), 1e-9)
  oa <- oc("oct_acf_network.tsv"); ra <- rd(file.path(D$res, "r_acf_network.tsv")); chk("Octave vs R: network-Z ACF lags 1..60", oa[[1]], ra$acf, 1e-6)
  op <- oc("oct_periodogram.tsv"); rp <- rd(file.path(D$res, "r_periodogram_peaks.tsv")); chk("Octave vs R: periodogram peak index k", op[[1]], rp$k[1], 0, "abs"); chk("Octave vs R: periodogram peak ordinate", op[[2]], rp$ordinate[1], 1e-6)
  chk("Octave vs R: mean periodogram ordinate", op[[3]], rd(file.path(D$res, "r_periodogram_summary.tsv"))$mean_ordinate[1], 1e-6)
  ow <- oc("oct_welch.tsv"); rw <- rd(file.path(D$res, "r_welch_psd.tsv")); chk("Octave vs R: Welch PSD (2049 bins; own implementation in both)", ow[[2]], rw$psd, 1e-6); chk("Octave vs R: Welch frequencies", ow[[1]], rw$freq_hz, 1e-7)
  orv <- oc("oct_roll60_dev1_var.tsv"); chk("Octave vs R: rolling-60 variance device 1 (qualified windows)", orv[[1]], rv[, 1], 1e-9)
}
P <- do.call(rbind, rows); write_tsv_num(P, "parity.tsv", sig = 6); print(P, row.names = FALSE, right = FALSE)
cat(sprintf("\nPARITY: %d PASS, %d FAIL, %d UNAVAILABLE\n", sum(P$status == "PASS"), sum(P$status == "FAIL"), sum(P$status == "UNAVAILABLE")))
quit(status = if (any(P$status == "FAIL")) 1 else 0)
