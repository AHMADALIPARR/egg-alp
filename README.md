# egg-alp

Three things in one repository:

1. **EGG-001**, a written research plan for studying random-number counts from a network of EGG devices (`spec/`).
2. **One day of EGG data**: 25 devices, 1 April 2000 (UTC), one row per second (`data/`).
3. **ALP**, a small C++ logic engine that reads Horn clauses (rules like "A is true if B and C are true"), with parsing, unification, inference, abduction and integrity constraints, plus an optional graph backend (`alp/`).

The plan, the data and the engine sit side by side. The EGG-001 analyses themselves are not written yet.

## What the data is

Each device reports, every second, how many of 200 coin-flip-style trials came up 1. If the devices behave like fair coins, the count is Binomial(200, 0.5): it centres on 100 with a spread (standard deviation) of about 7.07.

The file has 86,400 rows and 25 devices, so 2,160,000 cells. 2,145,238 hold a count and 14,762 are empty (no count recorded). The counts average 99.9999 and run from 62 to 136. Details are in [data/README.md](data/README.md).

![Share of the day each device reported a count](docs/img/coverage_per_device.png)

*Real data: for each of the 25 devices, the share of the 86,400 seconds that has a count. Device 33 is at 84.0% and device 110 at 99.0%; the other 23 are at or near 100%.*

![All counts compared with Binomial(200, 0.5)](docs/img/counts_vs_binomial.png)

*Real data: all 2,145,238 counts as bars, with the Binomial(200, 0.5) curve in red. This is a picture, not a statistical test.*

Both figures are made by `docs/scripts/make_figures.py` (needs numpy and matplotlib).

## Layout

```
spec/EGG-001.dspy.txt                  the EGG-001 research specification, as received
data/basketdata-2000-04-01.csv         the dataset, as received
data/SHA256SUMS                        checksum for the CSV
data/verify_data.py                    recomputes the dataset numbers from the CSV
data/README.md                         file format and verified numbers
alp/                                   the ALP logic engine, as received (source, tests, .alp libraries)
docs/ALP-BUILD.md                      build and test results for alp/
docs/img/, docs/scripts/               the two figures and the script that makes them
LICENSE                                SnapKitty Opaque Source License v1.0
```

## Check the data

```sh
cd data && sha256sum -c SHA256SUMS && cd ..
python3 data/verify_data.py
```

The first command confirms the CSV is the original file. The second recomputes the row count, device count, valid and missing counts, mean and range from the file, and compares them with the numbers in the spec. All of them match.

## Build and test the ALP code

```sh
cmake -S alp -B build -DALP_GRAPHBLAS_ENABLE=OFF
cmake --build build
ctest --test-dir build --output-on-failure
```

This builds the logic engine without the GraphBLAS graph backend, and the one test passes. The graph backend needs ALP/GraphBLAS installed and has not been run here. See [docs/ALP-BUILD.md](docs/ALP-BUILD.md).

## What this is not

- The analysis runtime described in EGG-001 has no AI, agents or language models. The spec uses a DSPy prompt only as a way to write the plan down.
- The data is historical. The file is fixed and can be replayed; it is not live.
- Nothing here claims consciousness has any effect on the devices, or anything about the universe being a simulation.

## License

Dual-licensed: AGPL-3.0, and the SnapKitty Opaque Source License v1.0 (the `LICENSE` file). Copyright Ahmad Ali Parr.
