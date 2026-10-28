# Data

`basketdata-2000-04-01.csv` is one day (2000-04-01, UTC) of counts from 25 EGG devices, one row per second. The file is kept exactly as received. Never edit it: check it against `SHA256SUMS` instead.

## Format

- Lines 1-8 are metadata:
  - `10,1..4`: samples per record = 10, seconds per record = 10, records per packet = 30, trial size = 200.
  - `11,1..4`: eggs reporting = 25, start time = 954547200 (2000-04-01 00:00:00), end time = 954633599 (2000-04-01 23:59:59), seconds of data = 86400.
- Line 9 is the header: `12,gmtime,,` followed by the 25 device IDs.
- Every later line is `13,<unix_seconds>,,` followed by 25 counts. An empty cell means no count was recorded for that device that second.
- Each count is the sum of 200 trials, so it sits around 100. These are counts, not raw random bytes.
- The "samples per record = 10" and "seconds per record = 10" header fields are copied from the source. They do not mean the rows are 10 seconds apart; rows are one second apart.

Device IDs, in column order: 1, 28, 33, 37, 100, 101, 102, 103, 107, 108, 109, 110, 111, 112, 114, 115, 116, 118, 1000, 1005, 1021, 1022, 1024, 1025, 1027.

## Check it yourself

```sh
cd data
sha256sum -c SHA256SUMS      # basketdata-2000-04-01.csv: OK
cd ..
python3 data/verify_data.py  # recomputes every number below, exits 0 if all pass
```

## Verified facts

Recomputed from the CSV on 2026-10-27 (America/Los_Angeles). Every claim in `spec/EGG-001.dspy.txt` about the file holds.

| Item | Spec says | Recomputed |
|---|---|---|
| SHA-256 | 63b52882...f209d77 | 63b52882582a8c7abd555f81002da6ce08c1161ec07526f422e6fdfcaf209d77 (match) |
| Data rows | 86,400 | 86,400 (one per second, 954547200 to 954633599, none skipped) |
| Devices | 25 | 25, IDs as listed above |
| Cells | 2,160,000 | 2,160,000 |
| Valid counts | 2,145,238 | 2,145,238 |
| Missing cells | 14,762 | 14,762 |
| Mean of valid counts | about 99.9999 | 99.999898 |
| Range | 62 to 136 | 62 to 136 |
| Counts outside 0-200 | none expected | none |

Also from the file: the standard deviation of all valid counts is 7.0706 (the Binomial(200, 0.5) value is sqrt(50) = 7.0711).

Missing cells by device:

| Device | Seconds with a count | Missing |
|---|---|---|
| 33 | 72,590 | 13,810 |
| 110 | 85,500 | 900 |
| 115 | 86,373 | 27 |
| 1000 | 86,375 | 25 |
| the other 21 devices | 86,400 | 0 |

These add up to 14,762.
