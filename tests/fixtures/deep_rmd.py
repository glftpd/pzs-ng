#!/usr/bin/env python3
"""deep_rmd.py BASE DATACLEANER: make a working directory just under PATH_MAX below
BASE (with relative mkdir()s; an absolute path that long can't be created), then exec
DATACLEANER "RMD victim" from it.  storage + cwd + name then no longer fits st[PATH_MAX]:
the fixed datacleaner refuses the path, the old one overflowed st on the stack."""
import os
import sys

base, datacleaner = sys.argv[1], sys.argv[2]
os.chdir(base)
os.makedirs("deep", exist_ok=True)
os.chdir("deep")
while len(os.getcwd()) < 4089:
    name = "d" * min(250, 4089 - len(os.getcwd()))
    os.makedirs(name, exist_ok=True)
    os.chdir(name)
os.makedirs("victim", exist_ok=True)
print(f"cwd length {len(os.getcwd())}", flush=True)
os.execv(datacleaner, [datacleaner, "RMD victim"])
