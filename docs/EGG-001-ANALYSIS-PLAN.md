# EGG-001 analysis plan (tests and parameters)

Status of this plan: written on branch `egg-001`. Be clear about timing:

* The AWK integrity step, the Futhark kernels and R scripts `01_device`, `02_network`
  and `03_rolling` were written and run **before** this file was committed.
  Their tests and parameters below are therefore *documented*, not pre-registered.
* Cross-device (`04`) was started before this file was written, but its results were
  not looked at until after. Time-series (`05`) and change-point (`06`) were written
  from the table below before they were run on the real data. In `05`, the follow-up on
  quarters of the day for flagged series was added after the first look. It is marked post hoc.
* The rolling-window family definition (BH over 75 tests per metric, plus all 225 together)
  was widened after a first look at the rolling results. Both versions are reported.
* There is no holdout date in this repository and no way to make one honestly.
  Every discovery in this experiment is exploratory. None is confirmed.

Data: `data/basketdata-2000-04-01.csv`, SHA-256
`63b52882582a8c7abd555f81002da6ce08c1161ec07526f422e6fdfcaf209d77`.
25 devices, 86,400 one-second rows, counts 0..200, missing cells empty. Never imputed.

## Null model

H0: every observed cell is Binomial(200, 1/2), cells independent.
Mean 100, variance 50. z = (X - 100) / sqrt(50).
H1: any reproducible deviation that survives the corrections below.

## Fixed seeds

Base seed 20000401. Each analysis derives its own seed from the base seed and a tag
(`seed_for(tag)` in `egg/r/lib.R`). Futhark simulation seed 20000401. Everything is
re-runnable and gives the same numbers.

## Tests

| ID | Question | Test | Null | Correction |
|----|----------|------|------|------------|
| T1 | Does each device follow Binomial(200, 1/2)? | Pearson X2 and LR G2 on pooled bins (expected count >= 5, tails pooled), df = bins - 1; Monte-Carlo p (B = 4000) | exact binomial | Holm and BH over 25 devices |
| T2 | Moments, tails, quantiles | mean/variance z-tests; exact two-sided tail probabilities at cut-offs; empirical vs exact quantiles | exact binomial | BH over devices |
| T3 | Network Z behaves like N(0,1)? | variance, tail counts vs exact expectation, exact per-second binomial p | sum of observed counts ~ Binomial(200 k, 1/2) | Bonferroni and BH over seconds |
| T4 | Cross-device covariance zero? | pairwise-complete Pearson r; Fisher-z p; max-T circular-shift p | independent circular shifts per device | BH (Fisher) and max-T (shift) over 300 pairs |
| T5 | Entropy and variance in windows | plug-in and Miller-Madow entropy, min-entropy, window variance, vs null simulated at the same n; windows of 60, 300, 1800 s, non-overlapping, device windows only if fully observed | exact binomial simulation, 20,000 draws | BH within each metric over 75 device x window tests; also BH over all 225 tests together (the conservative reading) |
| T6 | Lagged cross-correlation | max over 300 pairs and lags -60..60 s of the standardized product sum; null from 5,000 random relative shifts | circular shifts | max-T (family-wise) |
| T7 | Simultaneous tails | both devices with abs(X - 100) >= 14 in the same second; pair z; variance ratio of the number of devices in the tail per second; counts of seconds with >= 4, 5, 6 devices in the tail | exact tail probability, circular shifts | max-T for pairs |
| T8 | Autocorrelation | ACF, PACF to lag 60, Ljung-Box at lags 10 and 60, on network Z and on each device z | white noise | Bonferroni/BH over 26 series |
| T9 | Periodicity | periodogram of network Z; Welch PSD (Hann, 4096 s segments, 50% overlap); Fisher g test for the largest peak, Bonferroni and BH over Fourier frequencies | white noise (periodogram ordinates Exp(1)) | Bonferroni, BH |
| T10 | Mean shifts over time | CUSUM max statistic and penalized-likelihood segmentation (optimal partitioning, normal mean cost, variance 1) on network Z and the 25 device z series; missing cells compressed out, never filled | null simulations that reproduce the same missingness mask with exact binomial counts | BH over the 26 series; penalty calibrated on null simulations |

## Parameters, fixed

* Alpha 0.05 for corrected decisions. Raw p-values are always shown next to corrected ones.
* Entropy: log base 2, support 0..200, plug-in estimator, Miller-Madow bias term (K - 1) / (2 n ln 2) with K the number of observed bins.
* Block bootstrap: circular, block length 300 s, one set of blocks shared by all devices.
* Network windows qualify if at least 20 devices are complete in the window.
* Calibrated network Z: Z / sqrt(mean of the correlation matrix entries over the observed devices). Reported next to raw Z.

## What would count as a finding

A result counts only if its corrected p-value is below 0.05 in its declared family.
Even then it is a candidate. With no holdout date, nothing here is confirmed.

## Not in this experiment

Conditional entropy and mutual information (spec section G), wavelets and event/intention
comparisons (spec section O). There are no event or intention data in the CSV and none are invented.
