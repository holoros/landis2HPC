#!/usr/bin/env python3
"""Patch the TreeMap DRYBIO_L unit conversion in the LANDIS initial communities builders.

STAGED, NOT APPLIED (1 Oct 2026, session 33). Applying it changes every IC built afterwards,
so it waits for Aaron.

Defect. TreeMap 2022 DRYBIO_L is short tons per acre: the data dictionary defines it as
Sum(DRYBIO_BOLE, DRYBIO_TOP, DRYBIO_STUMP, DRYBIO_SAPLING, DRYBIO_WDLD_SPP) / 2000 * TPA_UNADJ,
and _variable_descriptions.csv gives the unit as tons/acre. The builders convert with
DRYBIO_L * 1000 * 0.4536 / 0.4047, which is 1000 lb per unit, so every cohort biomass and the
step 10 FIA check are half their true value. Correct factor: 2000 lb x 0.45359237 kg lb-1 /
0.40468564 ha ac-1 = 2241.70 kg ha-1 per ton ac-1 (224.17 g m-2).

Previous states hid it: the FIADB anchor (anchor_ic_to_fiadb.R) rescales the IC to the design
based total, with scale factors ME 2.253, GA 2.116, MN 1.494, NH 1.354. Anchored runs are
unaffected in total; what changes after the patch is the raw IC and the expected scale (about 1.3).

Usage: python3 patch_drybio_tons_20261001.py FILE [FILE ...]   (dry run)
       APPLY=1 python3 patch_drybio_tons_20261001.py FILE [...] (writes FILE, keeps FILE_PREV_20261001)
Each file must contain the anchor at least once; every occurrence is replaced and counted.
"""
import os, shutil, sys, hashlib

OLD = "DRYBIO_L * 1000 * 0.4536 / 0.4047"
NEW = "DRYBIO_L * 2000 * 0.45359237 / 0.40468564"
APPLY = os.environ.get("APPLY") == "1"
for f in sys.argv[1:]:
    s = open(f).read()
    n = s.count(OLD)
    if n == 0:
        print(f"{f}: anchor not found, skipped"); continue
    t = s.replace(OLD, NEW)
    print(f"{f}: {n} occurrence(s); md5 {hashlib.md5(s.encode()).hexdigest()} -> {hashlib.md5(t.encode()).hexdigest()}")
    if APPLY:
        root, ext = os.path.splitext(f)
        bak = f"{root}_PREV_20261001{ext}"
        if os.path.exists(bak): sys.exit(f"backup {bak} exists, refusing to overwrite")
        shutil.copy2(f, bak); open(f, "w").write(t)
        print(f"  written, backup {bak}")
if not APPLY: print("dry run; set APPLY=1 to write")
