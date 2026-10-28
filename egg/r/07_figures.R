# Figures for docs/EGG-001-REPORT.md. Reads only result files produced by the other steps. No new statistics except plot scales.
suppressMessages(library(ggplot2))
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
img <- D$img; dir.create(img, showWarnings = FALSE, recursive = TRUE)
rd <- function(f) read.delim(file.path(D$res, f), check.names = FALSE)
wrap <- function(x, w = 80) paste(strwrap(x, w), collapse = "\n")
th <- theme_minimal(base_size = 12) + theme(plot.title = element_text(face = "bold"), plot.subtitle = element_text(colour = "grey30"))
save <- function(p, name, w = 9, h = 5) ggsave(file.path(img, paste0("egg001-", name, ".png")), p, width = w, height = h, dpi = 110, bg = "white")

# 1 network Z series (per minute, scaled so each point is N(0,1) under the null) + per-second histogram vs N(0,1)
nm <- rd("r_network_z_minute.tsv"); nm$hour <- nm$minute / 60
p1 <- ggplot(nm, aes(hour, Z_mean_times_sqrt60)) + geom_hline(yintercept = c(-1.96, 1.96), colour = "firebrick", linetype = 2) +
  geom_line(colour = "grey40", linewidth = 0.3) + geom_point(size = 0.6) +
  labs(title = "Network Z, one value per minute", subtitle = wrap("Each point is the mean of 60 one-second Z values times sqrt(60). Under pure chance it is N(0,1). Dashed lines: +/-1.96."),
       x = "Hour of day (UTC), 2000-04-01", y = "Minute Z") + th
save(p1, "network-z")

# 2 correlation heatmap
cm <- rd("r_corr_matrix.tsv"); ids <- as.character(cm[[1]]); M <- as.matrix(cm[-1]); rownames(M) <- ids; colnames(M) <- ids
df <- expand.grid(a = factor(ids, ids), b = factor(ids, rev(ids))); df$r <- as.vector(M[cbind(as.character(df$a), as.character(df$b))])
df$r[as.character(df$a) == as.character(df$b)] <- NA
lim <- max(abs(df$r), na.rm = TRUE)
p2 <- ggplot(df, aes(a, b, fill = r)) + geom_tile() + scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b", limits = c(-0.05, 0.05), oob = scales::squish, na.value = "grey85") +
  labs(title = "Device-to-device correlation of per-second counts", subtitle = wrap(sprintf("Largest |r| is %.4f. The colour scale is fixed to +/-0.05 (grey = the diagonal). 95%% of pure-chance values are below 0.0136.", lim)),
       x = "Device", y = "Device", fill = "r") + th + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 8), axis.text.y = element_text(size = 8))
save(p2, "corr-heatmap", 8, 6.5)

# 3 per-device deviation chart
ds <- rd("r_device_summary.tsv"); n <- ds$n_valid
ds$z_var <- (ds$var_ratio_chi2 - (n - 1)) / sqrt(2 * (n - 1))
long <- rbind(data.frame(device = ds$device, stat = "Mean: z-score vs 100", z = ds$z_mean, cov = ds$coverage),
              data.frame(device = ds$device, stat = "Variance: z-score vs 50", z = ds$z_var, cov = ds$coverage),
              data.frame(device = ds$device, stat = "Shape (Pearson chi-square): z-score", z = qnorm(1 - ds$pearson_p), cov = ds$coverage))
long$device <- factor(long$device, rev(ds$device)); bonf <- qnorm(1 - 0.05 / 2 / 25)
p3 <- ggplot(long, aes(z, device, colour = cov < 0.95)) + geom_vline(xintercept = 0, colour = "grey60") +
  geom_vline(xintercept = c(-bonf, bonf), colour = "firebrick", linetype = 2) + geom_point(size = 2) + facet_wrap(~stat, nrow = 1) +
  scale_colour_manual(values = c("FALSE" = "black", "TRUE" = "darkorange"), labels = c("full", "device 33 (84% coverage)"), name = "") +
  labs(title = "Each device against Binomial(200, 1/2)", subtitle = wrap("Dashed lines: the Bonferroni limit for 25 devices (about 3.0). The closest is device 1000 on variance (z about -2.9, p_raw 0.004, corrected p 0.088, not significant)."), x = "z-score", y = "Device") + th + theme(legend.position = "bottom")
save(p3, "device-deviation", 10, 6.5)

# 4 rolling entropy (network pooled, 60 s windows and 300 s windows) with theory
rn <- rd("r_rolling_network_series.tsv"); rn$hour <- (rn$t_start - min(rn$t_start)) / 3600
th_H <- H_theory()
rn$w <- factor(paste(rn$window_s, "s windows"), paste(c(60, 300, 1800), "s windows"))
p4 <- ggplot(rn, aes(hour, H_mm)) + geom_hline(yintercept = th_H, colour = "firebrick") + geom_line(colour = "grey35", linewidth = 0.3) + geom_point(size = 0.5) + facet_wrap(~w, ncol = 1, scales = "free_y") +
  labs(title = "Rolling entropy of the counts (all devices pooled in each window)", subtitle = wrap(sprintf("Miller-Madow entropy in bits. Red line: exact Binomial(200, 1/2) entropy, %.4f bits.", th_H)), x = "Hour of day (UTC)", y = "Entropy (bits)") + th
save(p4, "rolling-entropy", 9, 7)

# 5 power spectrum (Welch) with expected white level and 95% null max line
wp <- rd("r_welch_psd.tsv"); wsum <- rd("r_welch_summary.tsv")
p5 <- ggplot(wp[wp$freq_hz > 0, ], aes(freq_hz, psd)) + geom_line(colour = "grey35", linewidth = 0.3) + geom_hline(yintercept = 1, colour = "firebrick") + geom_hline(yintercept = wsum$null_max_q95, colour = "firebrick", linetype = 2) +
  labs(title = "Power spectrum of network Z (Welch, 41 segments of 4096 s)", subtitle = wrap("Red line: level for pure noise (1). Dashed: the level the highest peak reaches in 5% of pure-noise runs. No peak crosses it."), x = "Frequency (Hz)", y = "Power") + th
save(p5, "power-spectrum")

# 6 ACF of network Z
ac <- rd("r_acf_network.tsv")
p6 <- ggplot(ac, aes(lag, acf)) + geom_hline(yintercept = 0) + geom_col(width = 0.6, fill = "grey35") + geom_hline(yintercept = c(-1, 1) * ac$band95[1], colour = "firebrick", linetype = 2) +
  labs(title = "Autocorrelation of network Z, lags 1 to 60 seconds", subtitle = wrap("Dashed: 95% band for white noise. About 3 of 60 bars may cross by chance; 4 do. Ljung-Box p = 0.10 (10 lags), 0.15 (60 lags)."), x = "Lag (s)", y = "ACF") + th
save(p6, "acf")

# 7 change-point candidates (needs step 06)
if (!file.exists(file.path(D$res, "r_changepoint_cusum_gain.tsv"))) stop("step 06 results missing: change-point figure not made")
cg <- rd("r_changepoint_cusum_gain.tsv")
cg$ord <- factor(cg$series, cg$series[order(cg$p_cusum, decreasing = TRUE)])
cg$sig <- cg$q_cusum_BH < 0.05
p7 <- ggplot(cg, aes(-log10(p_cusum), ord, colour = sig)) + geom_vline(xintercept = -log10(0.05 / nrow(cg)), colour = "firebrick", linetype = 2) + geom_point(size = 2.2) +
  scale_colour_manual(values = c("FALSE" = "black", "TRUE" = "firebrick"), guide = "none") +
  labs(title = "Change-point test (CUSUM) for each of 26 series", subtitle = wrap("Calibrated by exact-binomial null runs with the same missing cells (4000 runs). Dashed: Bonferroni limit. EXPLORATORY: no holdout date exists."),
       x = "-log10 p  (larger = stronger evidence)", y = "Series") + th
save(p7, "changepoints", 9, 6.5)
cat("figures done\n")
