# EGG-001 component: R shared helpers (statistical reference implementation).
# No agents, no LLM, no sampling from language models. Fixed seeds. Missing = NA, never 0.
suppressMessages({ library(jsonlite) })
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
EGG <- list(
  seed_base = 20000401L,        # all seeds below are derived from this
  n_trials = 200L, p = 0.5, mu = 100, sd = sqrt(50),
  windows = c(60L, 300L, 1800L),
  alpha = 0.05
)
args_dir <- function() {
  a <- commandArgs(trailingOnly = TRUE)
  list(out = if (length(a) >= 1) a[1] else "out", res = if (length(a) >= 2) a[2] else "results",
       img = if (length(a) >= 3) a[3] else "../docs/img")
}
D <- args_dir()
read_dense <- function(path = file.path(D$out, "dense.tsv")) {
  # empty cell -> NA (explicit missing). colClasses integer so nothing is coerced to 0.
  x <- read.delim(path, header = TRUE, check.names = FALSE, colClasses = "integer", na.strings = "")
  list(t = x[[1]], ids = names(x)[-1], X = as.matrix(x[-1]))
}
read_fut <- function(f, what = numeric()) {
  v <- read.delim(f, header = FALSE, na.strings = "NA", colClasses = "numeric")
  as.matrix(v)
}
read_fut_tbl <- function(f) read.delim(f, header = TRUE, na.strings = "NA")
binom_pmf <- function() dbinom(0:200, 200, 0.5)
H_theory <- function() { p <- binom_pmf(); -sum(p * log2(p)) }
Hmin_theory <- function() -log2(max(binom_pmf()))
# Shannon entropy (bits) of a count vector over bins; plug-in and Miller-Madow.
H_plugin <- function(cnt) { n <- sum(cnt); p <- cnt[cnt > 0] / n; -sum(p * log2(p)) }
H_mm <- function(cnt) { n <- sum(cnt); K <- sum(cnt > 0); H_plugin(cnt) + (K - 1) / (2 * n * log(2)) }
Hmin_plugin <- function(cnt) -log2(max(cnt) / sum(cnt))
z_of <- function(X) (X - EGG$mu) / EGG$sd
# Network Z, NA when no device observed (never divide by zero).
network_Z <- function(X) {
  Z <- z_of(X); k <- rowSums(!is.na(X)); s <- rowSums(Z, na.rm = TRUE)
  out <- rep(NA_real_, nrow(X)); ok <- k > 0; out[ok] <- s[ok] / sqrt(k[ok]); list(Z = out, k = k)
}
write_tsv <- function(df, name, dir = D$res, digits = 10) {
  f <- file.path(dir, name)
  write.table(format(df, digits = digits, scientific = FALSE, trim = TRUE, justify = "none"), f, sep = "\t", quote = FALSE,
              row.names = FALSE, na = "NA")
  invisible(f)
}
write_tsv_num <- function(df, name, dir = D$res, sig = 8) {
  # numbers with significant digits; NA stays NA
  f <- file.path(dir, name)
  df[] <- lapply(df, function(c) if (is.numeric(c) && !is.integer(c)) signif(c, sig) else c)
  write.table(df, f, sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
  invisible(f)
}
seed_for <- function(tag) { s <- sum(utf8ToInt(tag) * seq_along(utf8ToInt(tag))); EGG$seed_base + as.integer(s %% 100000L) }
