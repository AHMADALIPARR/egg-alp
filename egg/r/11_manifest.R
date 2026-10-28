# Reproducibility manifest (JSON). Everything in it is read from the machine or from files: nothing is typed in by hand.
# No signature is produced (no key was made); the manifest is a plain hash list, not an attestation.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), "lib.R"))
sh <- function(cmd) { r <- suppressWarnings(tryCatch(system(cmd, intern = TRUE, ignore.stderr = TRUE), error = function(e) character())); if (length(r)) r[1] else NA_character_ }
sha <- function(f) vapply(f, function(x) sub(" .*", "", sh(paste("sha256sum", shQuote(x)))), "")
root <- normalizePath(".."); csv <- file.path(root, "data", "basketdata-2000-04-01.csv")
tools <- list(R = R.version.string, jsonlite = as.character(packageVersion("jsonlite")), ggplot2 = as.character(packageVersion("ggplot2")),
  awk = sh("awk --version 2>&1 | head -1 || true"), futhark = sh("futhark --version | head -1"), octave = sh("octave --version | head -1"),
  gcc = sh("gcc --version | head -1"), python = sh("python3 --version"), sqlglot = sh("python3 -c 'import sqlglot;print(sqlglot.__version__)'"),
  dafny = sh("ls /workspace/tools/dafny/dafny >/dev/null 2>&1 && /workspace/tools/dafny/dafny --version"), lean = sh("lean --version"), elixir = sh("elixir --version 2>&1 | tail -1"),
  os = sh("uname -sr"), git_head = sh(sprintf("git -C %s rev-parse HEAD", shQuote(root))))
bins <- Sys.which(c("awk", "futhark", "octave", "Rscript", "gcc", "python3")); bins <- bins[nzchar(bins)]
dep_hash <- as.list(sha(unname(bins))); names(dep_hash) <- names(bins)
src_files <- c(Sys.glob("awk/*"), Sys.glob("futhark/*"), Sys.glob("r/*.R"), Sys.glob("r/*.c"), Sys.glob("octave/*"), Sys.glob("tests/*"), Sys.glob("tsql/*"), Sys.glob("sas/*"), Sys.glob("ampl/*"))
src_files <- src_files[file.info(src_files)$isdir %in% FALSE]
res_files <- c(setdiff(Sys.glob(file.path(D$res, "*")), file.path(D$res, "manifest.json")), Sys.glob(file.path(root, "docs", "img", "egg001-*.png")))
seed_tags <- unique(unlist(lapply(Sys.glob("r/*.R"), function(f) regmatches(readLines(f), gregexpr('seed_for\\("[^"]+"\\)', readLines(f))))))
seeds <- list(seed_base = EGG$seed_base, derivation = "seed_for(tag) in egg/r/lib.R", static_tags = setNames(lapply(sub('seed_for\\("(.*)"\\)', "\\1", seed_tags), function(tag) seed_for(tag)), sub('seed_for\\("(.*)"\\)', "\\1", seed_tags)),
  note = "Futhark simulations use explicit integer seeds passed on the command line (see egg/tests/futhark_sentinel.sh)")
summ <- file.path("out", "summary.tsv"); tests <- if (file.exists(summ)) { s <- read.delim(summ, header = FALSE, col.names = c("component", "status", "detail")); split(s[c("status", "detail")], s$component) |> lapply(function(x) as.list(x[1, ])) } else "run `make egg001` first"
par <- file.path(D$res, "parity.tsv"); parity <- if (file.exists(par)) { p <- read.delim(par); list(rows = nrow(p), by_status = as.list(table(p[[ncol(p)]]))) } else NA
sent <- if (file.exists("out/log/sentinel.log")) readLines("out/log/sentinel.log") else NA
m <- list(experiment = "EGG-001 first experiment", generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  input = list(file = "data/basketdata-2000-04-01.csv", sha256 = sha(csv), bytes = file.info(csv)$size),
  software_versions = tools, tool_binary_sha256 = dep_hash,
  parameters = list(null = "Binomial(200, 0.5)", windows_s = EGG$windows, alpha = EGG$alpha, changepoint_min_segment_s = 60, changepoint_null_sims_per_structure = 4000,
     crossdev_shift_sims = 1000, lag_shift_sims = 5000, bootstrap_resamples = 500, bootstrap_block_s = 300, welch = "periodic Hann, 4096 s, step 2048, 41 segments", holdout = "none exists; all findings are exploratory"),
  seeds = seeds, source_sha256 = as.list(sha(src_files)) |> setNames(src_files), output_sha256 = as.list(sha(res_files)) |> setNames(sub(paste0("^", root, "/"), "", res_files)),
  test_results = list(components = tests, parity = parity, futhark_sentinel_lines = sent),
  signature = "none: no signing key was produced; no identity attestation is made")
jsonlite::write_json(m, file.path(D$res, "manifest.json"), auto_unbox = TRUE, pretty = TRUE, na = "null")
cat("manifest written:", file.path(D$res, "manifest.json"), "-", length(res_files), "output hashes,", length(src_files), "source hashes\n")
