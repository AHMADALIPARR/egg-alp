# EGG-001 first experiment: report

One day of data (1 April 2000, UTC), 25 devices, one count per second. The question is simple: do the counts look like fair coin flips, or is something else going on?

Everything below comes from code that ran on this box, on the file `data/basketdata-2000-04-01.csv` (SHA-256 `63b52882…f209d77`). Every number can be found in `egg/results/`. The research code uses no AI, no agents and no sampling from a language model. Random numbers come only from fixed seeds.

## The short answer

**The data looks like fair coin flips.** Almost every test came out as "nothing here". One small result survived correction for multiple testing. It is a weak serial correlation in one device (1025). It was found on this one day, so it is a lead, not a finding.

## What we compared the data with

Each count is the number of "1"s out of 200 trials. If the device is a fair coin, the count follows a Binomial(200, 0.5) distribution. That centres on 100, with a standard deviation of 7.07. We call this the reference.

## What we found

All figures are real data. There were 20 tests in the headline table (`egg/results/headline.tsv`). Of these, 1 survived correction, 18 did not, and 1 is an estimate with no p-value.

**1. The counts match the reference.**
- All 2,145,238 counts pooled: Pearson test p = 0.39, likelihood-ratio test p = 0.40. No sign of any difference.
- Mean 99.9999 (reference 100). Variance 49.99 (reference 50).
- Entropy of the pooled counts: 4.8689 (reference 4.8690).
- Device by device, the smallest raw p-values were small but ordinary for 25 devices. The lowest was the variance of device 1000 (raw p = 0.0035). After correcting for 25 devices it is 0.088. Not significant.

![How far each device is from the reference](img/egg001-device-deviation.png)

**2. The network as a whole is flat.**
- We combined all devices each second into one score, Z. If everything is fair, Z has mean 0 and variance 1.
- Mean of Z: −0.0001. Variance: 1.0033 (block-bootstrap interval 0.993 to 1.014).
- Seconds with |Z| ≥ 3: 245 seen, 227 expected (p = 0.23).
- The most extreme second has a raw p of 1.9 × 10⁻⁶. With 86,400 seconds to look through, the corrected p is 0.16. That is what luck produces.

![Network score over the day](img/egg001-network-z.png)

**3. The devices do not move together.**
- Largest correlation between any two devices: 0.0092 (permutation p = 0.90).
- Lagged correlation up to ±60 seconds: nothing (p = 0.86).
- The number of devices in the tail each second shows no extra clumping (p = 0.14).

![Correlation between devices](img/egg001-corr-heatmap.png)

**4. Entropy and spread over time look normal.**
- We checked 60 s, 5 min and 30 min windows per device: mean, variance and entropy. About 1% of windows have p < 0.01, as expected by chance.
- Smallest corrected p over 225 rolling tests: 0.058. Nothing.

![Rolling entropy](img/egg001-rolling-entropy.png)

**5. No repeating pattern.**
- Periodogram of the network score: no peak above chance (p = 0.64). Welch spectrum: highest peak p = 0.49.
- Devices 33, 110, 115 and 1000 have gaps, so a plain spectrum can't be taken. They are not analysed this way. We did not fill the gaps.

![Power spectrum](img/egg001-power-spectrum.png)

**6. One weak serial correlation: device 1025. Exploratory.**
- This is the one result that survived correction. The test asks whether a second's count predicts the next few seconds' counts.
- Device 1025: Ljung-Box over 10 lags, Q = 33.9, raw p = 0.0002, corrected p = 0.010 (corrected over 52 tests).
- The effect is tiny. The lag-1 correlation is 0.0013.
- A follow-up in four 6-hour blocks of the same day shows it mostly in block 3 (p = 0.0008). That is a look at the same data again, not a new test.
- Treat it as a question for the next day of data. It does not stand as a result.

![Autocorrelation](img/egg001-acf.png)

**7. No change points.**
- We looked for a moment when a device or the network changed its average level. We tested 26 series (25 devices and the network).
- Method: a CUSUM test, plus a PELT segmentation. The penalty was set by simulation so that, on fair-coin data with the same missing cells, the chance of any false split in 26 series is 5%. We ran 4,000 simulations for that.
- Result: no series passes. The smallest CUSUM p was 0.058 (device 109), corrected 0.76. The smallest split-gain p was 0.019 (device 1022), corrected 0.27. At the calibrated penalty, PELT finds **0 change points in all 26 series**.
- Check on the method: on 40 fresh fair-coin network series, it also found 0.
- If the penalty is loosened to half, it finds 190 splits across the series. At three-quarters it finds 4. That is what a loose penalty does to noise, not a signal.
- These are **exploratory**. There is no holdout date, and none was made up.

![Change-point test per series](img/egg001-changepoints.png)

## Missing data and device 33

- 14,762 of 2,160,000 cells are empty (0.68%).
- Device 33 is missing 13,810 seconds. It reports only 84.0% of the day. That is 94% of all the gaps.
- Empty means "no count was recorded". It is never turned into a 0. Counts are kept as missing in every tool, and a test confirms the results do not depend on what is stored in a missing cell.
- The network score uses only the devices present each second (23 to 25). The variance is calibrated for this. Per-device tests use that device's own counts.
- Whether device 33's gaps are related to anything else is unknown. We have no information about why they happen.

## What this does and does not show

It shows that on this day these 25 devices behaved, within the power of these tests, like independent fair coins. It does not show that they always do. It is one day, one data set, one run of the checks.

It does not show anything about intention, attention, events or consciousness. We have no event or intention data. None was invented. It says nothing about simulations of any kind.

A null result here means "no departure found", not "proved none exists". Small effects could hide in one day of data. The serial correlation in device 1025 is the thing to look at first with more data.

## What was not done

- Conditional entropy and mutual information (section G of the spec). Not run.
- Wavelets. Not run.
- Any comparison with events. No event data exists.
- A holdout. None exists, so every positive result stays exploratory.

## How it was checked

`make egg001` runs every component that is installed and prints PASS, FAIL, UNAVAILABLE or PENDING. On the last run: 13 PASS, 3 UNAVAILABLE, 0 FAIL.

| Component | Status | What it means |
|---|---|---|
| Input checksum | PASS | File matches the expected SHA-256 |
| AWK inspection | PASS | Row count, columns, ranges, histogram and byte count checked; no failed integrity rows |
| Futhark kernels | PASS | Data-parallel versions of the per-device statistics ran |
| Futhark sentinel test | PASS | Output does not change when the value in a missing cell is changed; it does change with the seed |
| Octave spectral | PASS | Spectrum code ran under Octave |
| R analyses | PASS (not re-run) | The slow steps use the saved results from the recorded run. `FULL=1 make egg001-full` regenerates them (about 25 minutes) |
| Headline table | PASS | Rebuilt from the R results each run |
| Parity | PASS | 34 comparisons across AWK, Futhark, R and Octave agree: 0 fail |
| Dafny | PASS | 50 proof obligations verified, 0 errors. No `assume` or axiom in the file |
| Lean | PASS | Builds. No `sorry` in the file |
| Elixir runner | PASS | 13 tests, 0 failures |
| ALP contracts | PASS | Contract rules found no violation in the real facts. They did flag the deliberately broken test inputs |
| T-SQL | PASS (syntax only) | Parsed by sqlglot. Never run on SQL Server |
| SAS | UNAVAILABLE | Not installed. File written, not run |
| AMPL | UNAVAILABLE | No AMPL or solver installed. File written, not run |
| MATLAB | UNAVAILABLE | Not installed. The MATLAB-style code was only run under Octave |

Also:

- The C change-point code gives the same result as the plain R version on 6 small test series.
- `egg/results/manifest.json` lists the software versions, seeds, parameters, the input hash, hashes of every output and the test results.
- The manifest has no digital signature. No signing key was created, so no identity claim is made.
- The Dafny and Lean proofs cover the plan's finite arithmetic on missing cells: missing is not zero, counts add up, sums stay in range, network Z is only defined when a device reports. They do not cover entropy bounds, and they do not prove the statistics are right or say anything about the physical data.

## Reproduce

```sh
make egg001            # about 30 seconds; uses saved results for the slow R steps
make egg001-manifest   # writes egg/results/manifest.json
make egg001-full       # re-runs everything, about 25 minutes
```
