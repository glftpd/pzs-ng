#!/usr/bin/env python3
"""Print the results table for run.sh: one row per group, one column per mode.

Each result file is RES/<group>@<mode>: a "pass fail skip" line, then one line
per failed check.  Exit 1 if anything failed.
"""
import os
import sys
import unicodedata

res, modes = sys.argv[1], sys.argv[2].split()


def width(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def pad(s, w):
    return s + " " * (w - width(s))


groups = sorted({f.split("@")[0] for f in os.listdir(res)})
cells, failures = {}, []
for g in groups:
    for m in modes:
        try:
            with open(os.path.join(res, f"{g}@{m}")) as fh:
                lines = fh.read().splitlines()
        except FileNotFoundError:
            cells[g, m] = "—"
            continue
        p, f, s = (int(x) for x in lines[0].split())
        if f:
            cells[g, m] = f"❌ {p}/{p + f}"
            failures += [f"{g} [{m}]: {why}" for why in lines[1:]]
        elif s and not p:
            cells[g, m] = "⚪ skip"
        elif g == "00_build":
            cells[g, m] = "✅ ok"
        else:
            cells[g, m] = f"✅ {p}/{p}" + (f" +{s} skip" if s else "")

label = {g: g.replace("_", " ") for g in groups}
w0 = max(width(label[g]) for g in groups) + 2
wc = {m: max([width(m)] + [width(cells[g, m]) for g in groups]) + 2 for m in modes}

top = "┌" + "─" * w0 + "".join("┬" + "─" * wc[m] for m in modes) + "┐"
mid = "├" + "─" * w0 + "".join("┼" + "─" * wc[m] for m in modes) + "┤"
bot = "└" + "─" * w0 + "".join("┴" + "─" * wc[m] for m in modes) + "┘"
row = lambda first, rest: "│ " + pad(first, w0 - 1) + "".join("│ " + pad(c, wc[m] - 1) for m, c in zip(modes, rest)) + "│"

print("\n" + top)
print(row("", modes))
for g in groups:
    print(mid)
    print(row(label[g], [cells[g, m] for m in modes]))
print(bot)

if failures:
    print(f"\n{len(failures)} failure(s):")
    for line in failures:
        print("  " + line)
    sys.exit(1)
print("\nALL PASSED")
