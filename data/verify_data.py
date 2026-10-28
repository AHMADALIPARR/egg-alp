"""Check basketdata-2000-04-01.csv against the numbers in spec/EGG-001.dspy.txt.

Run from the repo root:  python3 data/verify_data.py
Uses only the Python standard library. Exits non-zero if any check fails.
"""
import csv
import hashlib
import sys
from pathlib import Path

path = Path(__file__).resolve().parent / "basketdata-2000-04-01.csv"
EXPECTED_SHA = "63b52882582a8c7abd555f81002da6ce08c1161ec07526f422e6fdfcaf209d77"

sha = hashlib.sha256(path.read_bytes()).hexdigest()
rows = list(csv.reader(open(path)))
ids = rows[8][3:]
data = rows[9:]
ts = [int(r[1]) for r in data]
vals, missing = [], 0
for r in data:
    for c in r[3:]:
        if c == "":
            missing += 1
        else:
            vals.append(int(c))
mean = sum(vals) / len(vals)

checks = [
    ("sha256", sha == EXPECTED_SHA),
    ("86,400 rows", len(data) == 86400),
    ("one row per second, 954547200..954633599", ts == list(range(954547200, 954633600))),
    ("25 devices", len(ids) == 25 and len(set(ids)) == 25),
    ("2,145,238 valid", len(vals) == 2145238),
    ("14,762 missing", missing == 14762),
    ("valid + missing = 2,160,000", len(vals) + missing == 2160000),
    ("mean rounds to 99.9999", round(mean, 4) == 99.9999),
    ("range 62-136", (min(vals), max(vals)) == (62, 136)),
    ("all counts within 0-200", min(vals) >= 0 and max(vals) <= 200),
]
print(f"sha256 {sha}")
print(f"rows {len(data)}  devices {len(ids)}  valid {len(vals):,}  missing {missing:,}  "
      f"mean {mean:.6f}  min {min(vals)}  max {max(vals)}")
ok = True
for name, passed in checks:
    print(("PASS  " if passed else "FAIL  ") + name)
    ok &= passed
sys.exit(0 if ok else 1)
