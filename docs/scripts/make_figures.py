"""Make the two figures in docs/img from data/basketdata-2000-04-01.csv.

Run from the repo root:  python docs/scripts/make_figures.py
Needs numpy and matplotlib.
"""
import csv
from math import comb
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

root = Path(__file__).resolve().parents[2]
rows = list(csv.reader(open(root / "data" / "basketdata-2000-04-01.csv")))
ids = rows[8][3:]
data = rows[9:]

counts = np.full((len(data), len(ids)), -1, dtype=int)
for t, r in enumerate(data):
    for j, c in enumerate(r[3:]):
        if c != "":
            counts[t, j] = int(c)
valid = counts >= 0
n_valid = int(valid.sum())

out = root / "docs" / "img"
out.mkdir(parents=True, exist_ok=True)

# Figure 1: share of the 86,400 seconds each device reported a count
cov = valid.sum(axis=0) / len(data) * 100
fig, ax = plt.subplots(figsize=(10, 4.2))
ax.bar(range(len(ids)), cov, color="#3b6ea5")
ax.set_xticks(range(len(ids)))
ax.set_xticklabels(ids, rotation=60)
ax.set_ylim(80, 100.5)
ax.set_xlabel(f"EGG device ID  ({n_valid:,} of 2,160,000 cells have a count)")
ax.set_ylabel("Seconds with a count (% of 86,400; axis starts at 80)")
ax.set_title("Coverage per device, 2000-04-01 UTC (basketdata-2000-04-01.csv)")
for j in (list(ids).index(d) for d in ("33", "110")):
    ax.text(j, cov[j] + 0.3, f"{cov[j]:.1f}%", ha="center", fontsize=8)
fig.tight_layout()
fig.savefig(out / "coverage_per_device.png", dpi=150)
plt.close(fig)

# Figure 2: all counts vs Binomial(200, 0.5)
vals = counts[valid]
ks = np.arange(0, 201)
pmf = np.array([comb(200, k) for k in ks], dtype=float) / 2.0**200
emp = np.bincount(vals, minlength=201) / vals.size
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.bar(ks, emp, width=1.0, color="#9db8d6", label=f"observed ({vals.size:,} counts)")
ax.plot(ks, pmf, color="#c0392b", lw=1.6, label="Binomial(200, 0.5)")
ax.set_xlim(55, 145)
ax.set_xlabel("Count in one trial of 200")
ax.set_ylabel("Fraction of counts")
ax.set_title(f"All device counts vs Binomial(200, 0.5); observed mean {vals.mean():.4f}, "
             f"SD {vals.std():.4f}, range {vals.min()}-{vals.max()}")
ax.legend()
fig.tight_layout()
fig.savefig(out / "counts_vs_binomial.png", dpi=150)
plt.close(fig)
print("ok", n_valid)
