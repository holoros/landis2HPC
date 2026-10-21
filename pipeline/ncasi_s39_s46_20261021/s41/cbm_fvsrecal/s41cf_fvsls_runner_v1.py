#!/usr/bin/env python3
"""
FVS Lake States (variant LS) state-scope runner, NCASI Model Evaluation Phase II.
REVISION OF 2026-09-07. Built on fvs_ls_state_scope_runner_DRAFT_2026-09-04.py,
which is left untouched. Everything in that file's docstring (sample frame,
location code 904, carbon route, climate, ownership, regeneration, restricted
data) still holds and is repeated below only where the 2026-09-07 change
touches it.

WHY THIS RERUN EXISTS, two reasons, both decided by Aaron on 2026-09-07.

  (a) Species resolution. The 2026-09-04 run pre-translated FIA SPCD to
      FVS alpha codes through the variant's FIAJSP table only and dropped
      every stem that table lacked (0.41 to 0.50 percent of usable stems
      in the Lake States). FVS itself resolves a code in two stages
      (base/intree.f90): FIAJSP first, then SPCTRN, the 562-row table in
      src-converted/vls/spctrn.f90 whose column 5 is the LS target, and a
      code with no row at all lands on the variant's "other" slot (LS 49,
      OH). The Southeast diagnosis (fvs-se/se-unmapped-stems-diagnosis_
      DRAFT_2026-09-06.md) showed the bypass mattered there (4.35 to 6.73
      percent dropped); it barely matters here, but all three regions are
      being rerun on the engine-faithful crosswalk so their provenance is
      uniform. This runner therefore passes EVERY usable live stem to
      inventory_keyfile.make_inventory_keyfile(..., use_spctrn=True,
      spctrn_other_fallback=True), which is FIAJSP, then SPCTRN, then OH,
      exactly the intree.f90 order, and logs how many stems each stage
      resolved, per state, per forest-type group and per SPCD.

      One LS wrinkle. The variant carries red pine, Pinus resinosa Aiton,
      twice (slot 3 RN and slot 7 RP, both FIA 125). FIAJSP keeps RP for
      125, so 125 never reaches SPCTRN, but SPCTRN's LS column sends the
      southern pines (110, 111, 121, 131, 136, 144) to RN, an alpha the
      FIAJSP crosswalk cannot produce and which the module admits through
      VARIANT_ALPHAS_NOT_IN_CROSSWALK = {"ls": {"RN"}}. The number of
      stems landing on RN is counted and logged.

  (b) Calibration file generation. The 2026-09-04 run read the April 2026
      generation ls.json (580,134 bytes, calibration.date 2026-04-08,
      pre-May-30 emitter). On 2026-09-06 ls.json on Cardinal was re-emitted
      with the current emitter (job 14268188, 21,831 bytes, calibration
      date 2026-09-06; April file preserved as ls_PREV_20260906.json) and
      shown to agree with the April file on what the engine reads (SDIMAX
      and MORTMULT byte identical, BAIMULT within 0.0013). This run is on
      the re-emitted file for strict same-generation provenance with the
      NE and SN arms. The runner verifies size and date and REFUSES to run
      on any other ls.json.

WHAT CHANGED AGAINST THE 2026-09-04 RUNNER, and what did not.

  Removed, because the patched inventory_keyfile.py (md5
  4804454a8aff48e948f659965fd597ee, branch commit 52fe7b5) now carries
  them itself and an override would only mask a regression:
    - the in-memory FIA_TO_FVS_SP["ls"] override. The module now has a
      66-entry "ls" table. It is CHECKED here to be identical to the
      crosswalk read from ls.json species_definitions, rather than
      replaced.
    - the in-memory STDINFO_DEFAULTS["ls"] override. The module now
      carries {"forest": 904, "fortyp_default": 901}; checked, not set.
    - the tree-list pre-filter to FIAJSP-mapped SPCDs. All usable stems
      go to the module, which resolves them in engine order.
  Kept:
    - the four structural checks on the 2026-08-27 keyfile fixes.
    - the sample frame gate "at least 5 live stems mapped by FIAJSP".
      This is deliberate. The 2026-09-04 draw (seed 20260904) is a
      function of the candidate list, and keeping the same gate keeps
      the same 900 stands, so old versus new is a paired comparison
      isolating the crosswalk and the ls.json generation. The runner
      logs how many stands the engine-faithful gate (>= 5 resolvable
      stems, which with the OH fallback is every stand with >= 5 usable
      stems) would additionally admit. --frame-gate resolved switches to
      that gate and breaks the pairing; it is not the default.
    - every other stand filter, the scenario logic, the carbon route
      (no CARBCALC, FFE method 0), the climate and ownership handling,
      the restricted-data discipline and the output schema.
  Corrected:
    - the describe_keywords() sentence "(it was inert in NE)". Measured
      on 2026-09-06 against the unchanged ne.json, 58 of 85 emitted NE
      SDIMAX values differ from the compiled sitset.f90 defaults, so
      SDIMAX was live in all three variants. The sentence now says so.

RESOLUTION COUNTS are computed twice and cross-checked. In the main
process, ik.resolve_fvs_code() is applied to every usable stem of every
candidate stand (per state, per forest-type group, per SPCD, per stage)
and again to the 900 sampled stands. In each worker, make_inventory_
keyfile() records its own counters, which are reset per call and
returned with the run record; the main process sums them over the
no_harvest default-arm runs (one per stand) and asserts they equal the
main-process count over the sampled stands. Both are written to the run
log and to fvs-ls-species-resolution_DATA_2026-09-07.csv.

Usage (Cardinal):
  python3 fvs_ls_state_scope_runner_DRAFT_2026-09-07.py \
      --fia-dir ~/fia_data --fvs-modern ~/fvs-modern \
      --fvs-bin ~/fvs-modern/src-converted/bin/FVSls \
      --scenarios ~/ncasi_fvsls/ma_06_scenarios.yml \
      --outdir ~/ncasi_fvsls/out_20260907 --n-per-state 300 --workers 32

Author: NCASI Model Evaluation Phase II working session
Date: 2026-09-07 (revision of the 2026-09-04 runner)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

import pandas as pd
import yaml

# --------------------------------------------------------------------------
# Unit conversions. Exact definitional factors only; no allometry, no fitted
# relationship, nothing derived. Identical to the Northeast runner so the two
# FVS arms are on one basis without anyone redoing the arithmetic downstream.
# --------------------------------------------------------------------------
FT2AC_TO_M2HA = 0.22956841       # ft^2 ac^-1 -> m^2 ha^-1
IN_TO_CM = 2.54                  # in -> cm
PERAC_TO_PERHA = 2.47105381      # ac^-1 -> ha^-1
FT3AC_TO_M3HA = 0.06997164       # ft^3 ac^-1 -> m^3 ha^-1
FT_TO_M = 0.3048                 # ft -> m
# short ton ac^-1 -> Mg ha^-1: 0.90718474 Mg per short ton divided by
# 0.40468564 ha per acre. The FVS Carbon Report prints "TONS/ACRE" and the
# FVS carbon documentation defines that as short (US) tons.
TONAC_TO_MGHA = 2.24170231

STATE_FIPS = {"MI": 26, "WI": 55, "MN": 27}

# FVS-LS location code. 904 = Huron-Manistee NF, one of the eight codes in
# ls/blkdat.f90 IFORCD. See module docstring for why 904 specifically and why
# the committed STDINFO_DEFAULTS fallback of 612 is invalid here.
LS_FOREST_CODE = 904

# The one ls.json this run may use: the 2026-09-06 re-emission (Cardinal job
# 14268188). Anything else, including the April generation the 2026-09-04
# run read, is refused.
LS_JSON_EXPECTED_BYTES = 21831
LS_JSON_EXPECTED_DATE = "2026-09-06"
# The patched keyfile module this run was written against.
IK_EXPECTED_MD5 = "4804454a8aff48e948f659965fd597ee"
RUN_DATE = "2026-09-07"

COND_COLS = [
    "CN", "PLT_CN", "INVYR", "STATECD", "CONDID", "COND_STATUS_CD",
    "CONDPROP_UNADJ", "OWNCD", "OWNGRPCD", "FORTYPCD", "STDAGE",
    "SICOND", "SIBASE", "SISP", "SLOPE", "ASPECT", "STDORGCD", "BALIVE",
]
TREE_COLS = [
    "PLT_CN", "CONDID", "STATUSCD", "SPCD", "DIA", "HT", "ACTUALHT",
    "CR", "TPA_UNADJ",
]
# PLOT.csv: CN/ELEV/MEASYEAR ONLY. No coordinate column is listed here and
# none may be added. See the FIA TRUE COORDINATES note in the docstring.
PLOT_COLS = ["CN", "ELEV", "MEASYEAR"]

# Columns that must never reach an output file. See the restricted-data note.
FORBIDDEN_OUT_COLS = {
    "PLT_CN", "plt_cn", "CN", "cn", "LAT", "LON", "lat", "lon",
    "LATITUDE", "LONGITUDE", "latitude", "longitude",
}

SUMMARY_FIELDS = [
    "year", "age", "tpa", "ba", "sdi", "ccf", "topht", "qmd",
    "tot_cuft", "merch_cuft", "sawlg_cuft", "merch_bdft",
    "rem_tpa", "rem_tot_cuft", "rem_merch_cuft", "rem_sawlg_cuft",
    "rem_merch_bdft",
    "res_ba", "res_sdi", "res_ccf", "res_topht", "res_qmd",
    "period_years", "accretion", "mortality", "mai_merch_cuft",
]


def safe_to_csv(df: pd.DataFrame, path: Path) -> None:
    """Write a CSV only after asserting no restricted identifier is present.

    The restricted-data guard at active-projects/ncasi-modeleval/
    restricted-data-guard/ is called when importable; otherwise the rule is
    applied here directly. Either way no file is written carrying PLT_CN or
    any coordinate column.
    """
    bad = sorted(set(df.columns) & FORBIDDEN_OUT_COLS)
    if bad:
        raise RuntimeError(
            f"REFUSING to write {path.name}: restricted columns present {bad}. "
            "PLT_CN is the join key to the Cardinal-side true-coordinate "
            "lookup and must never reach a workspace file."
        )
    df.to_csv(path, index=False)


# --------------------------------------------------------------------------
# Species crosswalk, read from the variant's own calibrated JSON
# --------------------------------------------------------------------------
def load_ls_species_crosswalk(fvs_modern: Path) -> dict[int, str]:
    """FIA SPCD -> FVS-LS two-letter alpha code, from ls.json.

    species_definitions.FIAJSP[i] is the FIA species code for LS species
    index i+1 and .JSP[i] is that species' FVS alpha code. This is the
    variant's own mapping as extracted from blkdat.f90, not a hand-built
    table. FIA SPCD 125 (red pine, Pinus resinosa Aiton) appears twice, as
    RN and RP; the later entry wins and both are red pine in the variant.
    """
    cfg = json.loads((fvs_modern / "config" / "calibrated" / "ls.json").read_text())
    sd = cfg["categories"]["species_definitions"]
    out: dict[int, str] = {}
    dups: list[int] = []
    for alpha, fia in zip(sd["JSP"], sd["FIAJSP"]):
        a = str(alpha).strip()
        f = str(fia).strip()
        if not a or not f:
            continue
        try:
            fi = int(f)
        except ValueError:
            continue
        if fi in out:
            dups.append(fi)
        out[fi] = a
    if len(out) < 60:
        raise RuntimeError(
            f"LS species crosswalk built only {len(out)} entries from ls.json; "
            "expected ~66 against a 68-species variant. Refusing to run on a "
            "truncated crosswalk."
        )
    return out


def check_ls_json_provenance(fvs_modern: Path, log: list[str]) -> None:
    """Refuse to run on anything but the 2026-09-06 re-emitted ls.json."""
    p = fvs_modern / "config" / "calibrated" / "ls.json"
    st = p.stat()
    cfg = json.loads(p.read_text())
    date = str(cfg.get("calibration", {}).get("date", ""))
    md5 = hashlib.md5(p.read_bytes()).hexdigest()
    mtime = datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
    log.append(f"ls.json loaded: {p} size {st.st_size} bytes, mtime {mtime}, "
               f"calibration.date {date}, md5 {md5}, r_version "
               f"{cfg.get('calibration', {}).get('r_version')}")
    if st.st_size != LS_JSON_EXPECTED_BYTES or date != LS_JSON_EXPECTED_DATE:
        raise RuntimeError(
            f"ls.json is not the 2026-09-06 re-emitted generation (expected "
            f"{LS_JSON_EXPECTED_BYTES} bytes, calibration.date "
            f"{LS_JSON_EXPECTED_DATE}; found {st.st_size} bytes, {date}). "
            "Refusing to run: the point of this rerun is same-generation "
            "provenance across the three FVS arms.")


def check_keyfile_module(ik, fvs_modern: Path, spmap: dict, log: list[str]) -> None:
    """Verify the patched module rather than override it."""
    path = Path(ik.__file__)
    md5 = hashlib.md5(path.read_bytes()).hexdigest()
    log.append(f"inventory_keyfile.py: {path} md5 {md5} "
               f"(expected {IK_EXPECTED_MD5}, match {md5 == IK_EXPECTED_MD5}); "
               f"SPCTRN_ROW_COUNT {ik.SPCTRN_ROW_COUNT}, SPCTRN_FIA_ROW_COUNT "
               f"{ik.SPCTRN_FIA_ROW_COUNT}, SPCTRN_SOURCE {ik.SPCTRN_SOURCE}")
    if md5 != IK_EXPECTED_MD5:
        raise RuntimeError("inventory_keyfile.py md5 differs from the patched "
                           "module this runner was written against; refusing.")
    ls_tab = ik.species_table("ls")
    if ls_tab != spmap:
        diff = {k for k in set(ls_tab) | set(spmap)
                if ls_tab.get(k) != spmap.get(k)}
        raise RuntimeError(f"module FIA_TO_FVS_SP['ls'] differs from the "
                           f"ls.json crosswalk on SPCD {sorted(diff)}; refusing.")
    sd = ik.stdinfo_defaults("ls")
    if sd["forest"] != LS_FOREST_CODE:
        raise RuntimeError(f"module STDINFO_DEFAULTS['ls'] forest is "
                           f"{sd['forest']}, expected {LS_FOREST_CODE}")
    sp = ik.spctrn_table("ls")
    rn = sorted(k for k, v in sp.items() if v == "RN")
    log.append(f"module FIA_TO_FVS_SP['ls'] has {len(ls_tab)} entries and equals "
               f"the ls.json species_definitions crosswalk; STDINFO_DEFAULTS"
               f"['ls'] = {sd}; SPCTRN LS column resolves {len(sp)} FIA codes, "
               f"of which {sorted(rn)} go to RN (admitted via "
               f"VARIANT_ALPHAS_NOT_IN_CROSSWALK {ik.VARIANT_ALPHAS_NOT_IN_CROSSWALK}); "
               f"other-slot fallback {ik.SPCTRN_OTHER_FALLBACK['ls']}. No in-memory "
               "override of either dictionary is applied in this run.")


def resolve_stems(ik, spcds: pd.Series) -> tuple[pd.Series, pd.Series]:
    """Main-process species resolution, same function the module uses."""
    cache: dict[int, tuple] = {}
    alphas, stages = [], []
    for c in spcds.astype(int).tolist():
        r = cache.get(c)
        if r is None:
            r = ik.resolve_fvs_code(c, "ls", use_spctrn=True, other_fallback=True)
            cache[c] = r
        alphas.append(r[0])
        stages.append(r[1])
    return (pd.Series(alphas, index=spcds.index, dtype=object),
            pd.Series(stages, index=spcds.index, dtype=object))


def new_res_counter() -> dict:
    return {"stands": 0, "total_stems": 0, "fiajsp_stems": 0,
            "spctrn_stems": 0, "other_stems": 0, "dropped_stems": 0,
            "spctrn_by_spcd": Counter(), "other_by_spcd": Counter(),
            "rn_stems": 0, "spctrn_alpha": Counter()}


def add_res(c: dict, alphas: pd.Series, stages: pd.Series,
            spcds: pd.Series) -> None:
    c["stands"] += 1
    c["total_stems"] += int(len(stages))
    for k in ("fiajsp", "spctrn", "other"):
        c[f"{k}_stems"] += int((stages == k).sum())
    c["dropped_stems"] += int(stages.isna().sum())
    c["spctrn_by_spcd"].update(spcds[stages == "spctrn"].astype(int).tolist())
    c["other_by_spcd"].update(spcds[stages == "other"].astype(int).tolist())
    c["spctrn_alpha"].update(alphas[stages == "spctrn"].tolist())
    c["rn_stems"] += int((alphas == "RN").sum())


def fmt_res(label: str, c: dict) -> str:
    n = c["total_stems"]
    def pct(x):
        return 100.0 * x / n if n else 0.0
    top = ", ".join(f"{k}:{v}" for k, v in c["spctrn_by_spcd"].most_common(8))
    oth = ", ".join(f"{k}:{v}" for k, v in c["other_by_spcd"].most_common(8))
    return (f"{label}: {c['stands']} stands, {n} stems; FIAJSP {c['fiajsp_stems']} "
            f"({pct(c['fiajsp_stems']):.3f}%), SPCTRN {c['spctrn_stems']} "
            f"({pct(c['spctrn_stems']):.3f}%), other slot OH {c['other_stems']} "
            f"({pct(c['other_stems']):.3f}%), dropped {c['dropped_stems']} "
            f"({pct(c['dropped_stems']):.3f}%); stems on RN {c['rn_stems']}; "
            f"SPCTRN by SPCD [{top}]; other by SPCD [{oth}]; SPCTRN targets "
            f"{dict(c['spctrn_alpha'].most_common(6))}")


def res_to_rows(state: str, frame: str, group: str, c: dict) -> list[dict]:
    """Long-form rows for the species-resolution CSV. No stand identifier."""
    rows = []
    base = {"state": state, "frame": frame, "fortyp_group": group,
            "n_stands": c["stands"], "total_stems": c["total_stems"]}
    for k in ("fiajsp", "spctrn", "other", "dropped"):
        rows.append({**base, "stage": k, "spcd": "all", "alpha": "",
                     "stems": c[f"{k}_stems"]})
    rows.append({**base, "stage": "spctrn", "spcd": "all", "alpha": "RN",
                 "stems": c["rn_stems"]})
    for k, v in sorted(c["spctrn_by_spcd"].items()):
        rows.append({**base, "stage": "spctrn", "spcd": k, "alpha": "",
                     "stems": v})
    for k, v in sorted(c["other_by_spcd"].items()):
        rows.append({**base, "stage": "other", "spcd": k, "alpha": "OH",
                     "stems": v})
    return rows


def load_calibrated_keywords(fvs_modern: Path) -> str:
    """Calibrated FVS-LS keyword block via the repo's own config loader."""
    sys.path.insert(0, str(fvs_modern))
    from config.config_loader import FvsConfigLoader  # noqa: E402
    loader = FvsConfigLoader("ls", version="calibrated",
                             config_dir=str(fvs_modern / "config"))
    return loader.generate_keywords(include_comments=False)


def describe_keywords(block: str, fvs_modern: Path) -> str:
    """Report what the emitted block actually contains, measured not assumed.

    The Northeast run established that a keyword can be emitted and still be
    inert, because its values equal the variant's own compiled defaults. That
    is checked here for SDIMAX against ls/sitset.f90's DATA SDICON block
    rather than inferred from the JSON's component list.
    """
    counts: dict[str, int] = {}
    vals: dict[str, list[float]] = {}
    sdimax: dict[int, float] = {}
    for line in block.splitlines():
        p = line.split()
        if not p:
            continue
        counts[p[0]] = counts.get(p[0], 0) + 1
        if len(p) >= 3:
            try:
                v = float(p[2])
            except ValueError:
                continue
            vals.setdefault(p[0], []).append(v)
            if p[0] == "SDIMAX":
                sdimax[int(p[1])] = v

    # Parse the compiled SDICON defaults straight out of the Fortran.
    src = (fvs_modern / "src-converted" / "ls" / "sitset.f90").read_text()
    i = src.index("DATA SDICON /")
    blob = src[i + len("DATA SDICON /"):src.index("/", i + 20)]
    comp = [float(x) for x in blob.replace("&", " ").replace("\n", " ")
            .replace(".", ". ").split() if x.replace(".", "").isdigit()]
    n_diff = sum(1 for k, v in sdimax.items()
                 if k <= len(comp) and abs(v - comp[k - 1]) > 0.5)

    parts = [f"{k}={n}" for k, n in sorted(counts.items())]
    rng = []
    for k in ("MORTMULT", "BAIMULT"):
        if k in vals:
            rng.append(f"{k} range {min(vals[k]):.4g} to {max(vals[k]):.4g}")
    return (f"calibrated keyword block: {', '.join(parts)}; "
            f"{'; '.join(rng)}; SDIMAX differs from the compiled sitset.f90 "
            f"SDICON default for {n_diff} of {len(sdimax)} emitted species, "
            "so SDIMAX is LIVE in this variant. Corrected 2026-09-07: the "
            "2026-09-04 log said it was inert in NE; measured 2026-09-06 "
            "against the unchanged ne.json, 58 of 85 emitted NE SDIMAX "
            "values differ from the compiled defaults, so it was live there "
            "too.")


# --------------------------------------------------------------------------
# FIA extraction
# --------------------------------------------------------------------------
def extract_state(fia_dir: Path, st: str, log: list[str]):
    """Return (stands DataFrame, trees DataFrame) for one state.

    Stand selection rules, all stated rather than implicit, and identical to
    the Northeast runner so the two FVS arms share a sample frame definition:
      - COND_STATUS_CD == 1 (accessible forest land)
      - CONDPROP_UNADJ >= 0.95, so the plot's tree list represents
        essentially the whole plot and a per-acre expansion is meaningful
      - STDAGE > 0 (FVS STDINFO needs a real stand age)
      - SICOND > 0 and SIBASE == 50. SIBASE is ENFORCED, not assumed, the
        same discipline ma_07_glfps_build.R applies for GLFPS: FVS-LS site
        index is base age 50 and no documented conversion exists from
        another base for these curves, so a stand on another base is
        skipped and logged rather than re-based.
      - most recent INVYR per plot location
      - at least 5 mapped live trees
    """
    cond = pd.read_csv(fia_dir / f"{st}_COND.csv", usecols=COND_COLS,
                       low_memory=False)
    n0 = len(cond)
    cond = cond[cond["COND_STATUS_CD"] == 1]
    n1 = len(cond)
    cond = cond[cond["CONDPROP_UNADJ"] >= 0.95]
    n2 = len(cond)
    cond = cond[(cond["STDAGE"] > 0) & cond["STDAGE"].notna()]
    n3 = len(cond)
    cond = cond[(cond["SICOND"] > 0) & cond["SICOND"].notna()]
    n4 = len(cond)
    n_sibase_bad = int((cond["SIBASE"] != 50).sum())
    cond = cond[cond["SIBASE"] == 50]
    n5 = len(cond)

    # most recent visit per plot
    cond = cond.sort_values("INVYR").drop_duplicates(subset=["PLT_CN"],
                                                     keep="last")
    cond = cond.sort_values(["PLT_CN", "CONDID"]).drop_duplicates(
        subset=["PLT_CN"], keep="first")

    plot = pd.read_csv(fia_dir / f"{st}_PLOT.csv", usecols=PLOT_COLS,
                       low_memory=False)
    cond = cond.merge(plot.rename(columns={"CN": "PLT_CN"}), on="PLT_CN",
                      how="left")

    keep = set(cond["PLT_CN"].astype("int64").tolist())
    condid = dict(zip(cond["PLT_CN"].astype("int64"), cond["CONDID"]))

    chunks = []
    for ch in pd.read_csv(fia_dir / f"{st}_TREE.csv", usecols=TREE_COLS,
                          chunksize=500_000, low_memory=False):
        ch = ch[ch["PLT_CN"].isin(keep)]
        if len(ch):
            chunks.append(ch)
    trees = pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame(
        columns=TREE_COLS)

    trees = trees[trees["STATUSCD"] == 1]
    trees["_cid"] = trees["PLT_CN"].astype("int64").map(condid)
    trees = trees[trees["CONDID"] == trees["_cid"]]
    trees["HT"] = trees["HT"].fillna(trees["ACTUALHT"])
    n_tree_raw = len(trees)
    trees = trees[trees["DIA"].notna() & (trees["DIA"] >= 1.0)]
    trees = trees[trees["HT"].notna() & (trees["HT"] > 0)]
    trees = trees[trees["CR"].notna() & (trees["CR"] > 0)]
    trees = trees[trees["TPA_UNADJ"].notna() & (trees["TPA_UNADJ"] > 0)]
    n_tree_ok = len(trees)

    log.append(
        f"{st}: COND {n0} -> status1 {n1} -> condprop>=0.95 {n2} -> "
        f"stdage>0 {n3} -> sicond>0 {n4} -> sibase==50 {n5} "
        f"(skipped {n_sibase_bad} on a non-50 site index base); "
        f"trees {n_tree_raw} -> usable {n_tree_ok}"
    )
    return cond, trees


# --------------------------------------------------------------------------
# Scenario logic, read from ma_06_scenarios.yml, nothing invented here
# --------------------------------------------------------------------------
def owner_regime(owngrpcd) -> str:
    """FIA OWNGRPCD -> ma_06_scenarios.yml owner regime name.

    OWNGRPCD 40 (Private) maps to NIPF, NOT Industrial, because FIA
    condition-level ownership cannot separate the two. See OWNERSHIP in the
    module docstring. Same choice OSM, GLFPS, PMRC and FVS-NE made.
    """
    try:
        g = int(owngrpcd)
    except (TypeError, ValueError):
        return "NIPF"
    if g == 40:
        return "NIPF"
    if g == 30:
        return "State"
    if g in (10, 20):
        return "Public-Other"
    return "NIPF"


def harvest_years(scen: dict, regimes: dict, rule: dict, regime: str,
                  horizon: int) -> tuple[list[int], float, str]:
    """Return (offsets in years from inventory, removal fraction, note).

    Scaling is carried verbatim from ma_06_scenarios.yml's
    regime_scaling_rule, which itself carries scale_reg() from
    ycx_02_perseus.R. Nothing new is introduced.
    """
    if not scen.get("rotation_scale"):
        return [], 0.0, "no_harvest baseline, growth only"
    reg = regimes[regime]
    if reg["type"] == "clearcut":
        # Unreachable in this run: OWNGRPCD cannot yield Industrial.
        return [], 0.0, "clearcut regime unreachable, see OWNERSHIP"
    e = max(int(rule["partial_entry_floor"]),
            round(reg["E"] * scen["rotation_scale"]))
    f = min(float(rule["removal_fraction_cap"]),
            reg["f"] * scen["removal_scale"])
    # FVS cycles are 5 years, so entries snap to the cycle boundary
    e = max(5, int(round(e / 5.0) * 5))
    yrs = list(range(e, horizon + 1, e))
    return yrs, f, f"partial entry every {e} yr, removal fraction {f:.3f}"


# --------------------------------------------------------------------------
# One FVS run
# --------------------------------------------------------------------------
def parse_sum(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("-999"):
            continue
        p = line.split()
        if len(p) < 26:
            continue
        try:
            vals = [float(x) for x in p[:26]]
        except ValueError:
            continue
        rows.append(dict(zip(SUMMARY_FIELDS, vals)))
    return rows


def parse_carbon(path: Path) -> dict[int, dict]:
    """Parse the FVS Fire and Fuels Extension STAND CARBON REPORT from .out.

    Columns as printed: YEAR, Aboveground Live Total, Aboveground Live Merch,
    Belowground Live, Belowground Dead, Standing Dead, DDW, Forest Floor,
    Shrub/Herb, Total Stand Carbon, Total Removed Carbon, Carbon Released
    from Fire. All in short tons per acre. No CARBCALC keyword is set, so
    these are FFE method 0 values, carbon equal to biomass times 0.5 with
    aboveground live from BIOLIVE. See the CARBON note in the docstring.
    """
    out: dict[int, dict] = {}
    lines = path.read_text().splitlines()
    try:
        i = next(k for k, l in enumerate(lines) if "STAND CARBON REPORT" in l)
    except StopIteration:
        return out
    for line in lines[i:i + 200]:
        p = line.split()
        # 12 fields: year plus the eleven columns listed above.
        if len(p) != 12:
            continue
        try:
            v = [float(x) for x in p]
        except ValueError:
            continue
        yr = int(v[0])
        if yr < 1900 or yr > 2200:
            continue
        out[yr] = {
            "c_abg_live_tonac": v[1],
            "c_abg_live_merch_tonac": v[2],
            "c_total_stand_tonac": v[9],
            "c_total_removed_tonac": v[10],
        }
    return out


def run_one(job: dict) -> dict:
    """Build a keyfile, run FVSls, parse the summary. Returns a record."""
    sys.path.insert(0, job["fvs_modern"])
    sys.path.insert(0, str(Path(job["fvs_modern"]) / "calibration" / "python"))
    import inventory_keyfile as ik

    # No in-memory override. The patched module carries the LS crosswalk and
    # location code itself; both were verified in main() before dispatch.
    ik.reset_unmapped_stem_counts()

    stand_df = pd.DataFrame([job["stand"]])
    tree_df = pd.DataFrame(job["trees"])

    kw_lines = []
    # Fire and Fuels Extension carbon report. No CARBCALC keyword is set, so
    # FFE runs its documented default (method 0). Stated, not implicit.
    kw_lines.append("FMIN\nCARBREPT\nCARBCUT\nEND")
    if job["cal_keywords"]:
        kw_lines.append(job["cal_keywords"])
    if job.get("fixmort_fa"):
        kw_lines.append(fixmort_cycles(job["fixmort_fa"], 5, job["num_cycles"], int(job["stand"]["inv_year"])))
    for y in job["harvest_offsets"]:
        cal_year = int(job["stand"]["inv_year"]) + int(y)
        kw_lines.append(
            "THINDBH   "
            f"{float(cal_year):>10.0f}"
            f"{0.0:>10.1f}"
            f"{999.0:>10.1f}"
            f"{job['removal_fraction']:>10.4f}"
        )
    key = ik.make_inventory_keyfile(
        stand_df=stand_df,
        tree_df=tree_df,
        stand_id=job["stand_id"],
        variant="ls",
        inv_year=int(job["stand"]["inv_year"]),
        num_cycles=job["num_cycles"],
        calibration_keywords="\n".join(kw_lines),
        use_spctrn=True,
        spctrn_other_fallback=True,
    )
    rc = ik.get_species_resolution_counts("ls")
    res_counts = {k: (dict(v) if isinstance(v, Counter) else v)
                  for k, v in rc.items()}

    work = tempfile.mkdtemp(prefix="fvsls_", dir=job["scratch"])
    try:
        kp = Path(work) / "s.key"
        kp.write_text(key)
        env = dict(os.environ)
        # Keep the opt-in Greg DG/HG climate kernels off. LS has no climate
        # token at all, so this is belt and braces rather than load bearing.
        env.pop("FVS_GREGDG", None)
        env.pop("FVS_GREGHG", None)
        r = subprocess.run([job["fvs_bin"], "--keywordfile=s.key"],
                           cwd=work, env=env, capture_output=True,
                           timeout=300)
        sp = Path(work) / "s.sum"
        if not sp.exists():
            return {"stand_id": job["stand_id"], "ok": False,
                    "reason": f"no s.sum, rc={r.returncode}"}
        rows = parse_sum(sp)
        if not rows:
            return {"stand_id": job["stand_id"], "ok": False,
                    "reason": "empty summary"}
        carbon = parse_carbon(Path(work) / "s.out")
        return {"stand_id": job["stand_id"], "ok": True, "rows": rows,
                "carbon": carbon, "res_counts": res_counts,
                "state": job["state"], "scenario": job["scenario"],
                "arm": job["arm"], "regime": job["regime"],
                "inv_year": int(job["stand"]["inv_year"]),
                "site_index": job["stand"]["site_index"],
                "age0": job["stand"]["age"],
                "fortypcd": job["stand"].get("forest_type")}
    except subprocess.TimeoutExpired:
        return {"stand_id": job["stand_id"], "ok": False, "reason": "timeout"}
    finally:
        shutil.rmtree(work, ignore_errors=True)


# --------------------------------------------------------------------------

# ---- s41 cbm_fvsrecal additions (16 Oct 2026). Copied verbatim from
# fvsmr_run_20261015e.py (md5 769527f6...), modkw unchanged; FIXMORT written once
# per 5 yr cycle start with cycle proportion 1-(1-fa)^5 so the annual rate fa is
# preserved for the 5 yr cycles this runner uses.
def modkw(cal, kB=1.0, PL=55.0, PU=85.0, kS=1.0):
    """Recalibrated mortality keywords inside the calibrated block. Growth keywords untouched."""
    out, put_mm = [], False
    for l in cal.split("\n"):
        if l.startswith("MORTMULT"):
            if not put_mm:
                out.append(f"{'MORTMULT':<10}{'':>10}{0:>10d}{kB:>10.4f}{0.0:>10.1f}{999.0:>10.1f}")
                put_mm = True
            if kB != 1.0:
                sp, m, d1, d2 = l[20:30], float(l[30:40]), l[40:50], l[50:60]
                l = f"{'MORTMULT':<10}{'':>10}{sp}{m * kB:>10.4f}{d1}{d2}"
        elif l.startswith("SDIMAX") and kS != 1.0:
            l = f"{l[:20]}{float(l[20:30]) * kS:>10.1f}{l[30:]}"
        out.append(l)
    if not put_mm:
        out.append(f"{'MORTMULT':<10}{'':>10}{0:>10d}{kB:>10.4f}{0.0:>10.1f}{999.0:>10.1f}")
    out.append(f"{'SDIMAX':<10}{'':>10}{'':>10}{'':>10}{'':>10}{PL:>10.1f}{PU:>10.1f}")
    return "\n".join(out)


def fixmort_cycles(fa, n, ncyc, y0):
    if not fa:
        return ""
    p = 1.0 - (1.0 - fa) ** n
    return "\n".join(f"{'FIXMORT':<10}{str(int(y0) + n * c):>10}{0:>10d}{p:>10.6f}{0.0:>10.1f}{999.0:>10.1f}{1:>10d}{0:>10d}" for c in range(ncyc))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fia-dir", required=True)
    ap.add_argument("--fvs-modern", required=True)
    ap.add_argument("--fvs-bin", required=True)
    ap.add_argument("--scenarios", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--states", default="MI,WI,MN")
    ap.add_argument("--n-per-state", type=int, default=300)
    ap.add_argument("--horizon", type=int, default=50)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--seed", type=int, default=20260904)
    ap.add_argument("--scratch", default="/tmp")
    ap.add_argument("--frame-gate", choices=["fiajsp", "resolved"],
                    default="fiajsp",
                    help="Sample-frame gate. fiajsp (default) keeps the "
                         "2026-09-04 gate so the seeded draw reproduces the "
                         "same 900 stands; resolved uses the engine-faithful "
                         "gate and breaks the pairing.")
    ap.add_argument("--arms", default="default,calibrated")
    ap.add_argument("--scenario-ids", default="")
    ap.add_argument("--recal", default="", help="ST:kS:fa,... per state")
    ap.add_argument("--recal-pl", type=float, default=55.0)
    ap.add_argument("--recal-pu", type=float, default=95.0)
    ap.add_argument("--s41-out-date", default="2026-10-16")
    a = ap.parse_args()

    fia_dir = Path(a.fia_dir).expanduser()
    fvs_modern = Path(a.fvs_modern).expanduser()
    outdir = Path(a.outdir).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)
    random.seed(a.seed)

    log: list[str] = []

    # Verify the five 2026-08-27 keyfile fixes are present before use, rather
    # than rediscovering them. Checked against the generated keyfile text of a
    # trivial probe stand further down; here the structural checks that can be
    # made from the module source itself.
    sys.path.insert(0, str(fvs_modern / "calibration" / "python"))
    import inventory_keyfile as ik  # noqa: E402
    import inspect  # noqa: E402
    src = inspect.getsource(ik.make_inventory_keyfile)
    # TREEFMT appears in that function only as an explanatory comment; what
    # matters is that no TREEFMT keyword line is ever emitted, so the FVS
    # default supplemental-record layout from base/intree.f90 is used.
    checks = {
        "no TREEFMT keyword emitted (fix 1 and 3)":
            'lines.append("TREEFMT' not in src,
        "TREEDATA carries 15 (fix 2)":
            '"TREEDATA  "' in src and "15.0" in src,
        "STDINFO age in field 3 with site index on SITECODE (fix 4)":
            "SITECODE" in src and 'f"{age:>10.0f}"' in src,
        "DESIGN per-acre fixed plot, BAF -1 (fix 5)":
            '"DESIGN    "' in src and "-1.0" in src,
    }
    for k, v in checks.items():
        log.append(f"keyfile fix verified present: {k} -> {v}")
    missing = [k for k, v in checks.items() if not v]
    if missing:
        raise RuntimeError(
            f"A 2026-08-27 inventory_keyfile.py fix is missing: {missing}; "
            "refusing to run.")
    check_ls_json_provenance(fvs_modern, log)
    spmap = load_ls_species_crosswalk(fvs_modern)
    log.append(f"LS species crosswalk: {len(spmap)} FIA SPCD entries from "
               f"config/calibrated/ls.json species_definitions")
    check_keyfile_module(ik, fvs_modern, spmap, log)

    cal_kw = load_calibrated_keywords(fvs_modern)
    log.append(describe_keywords(cal_kw, fvs_modern))

    scen_cfg = yaml.safe_load(Path(a.scenarios).expanduser().read_text())
    regimes = {k: v for k, v in scen_cfg["owner_regimes"].items()
               if isinstance(v, dict)}
    rule = scen_cfg["regime_scaling_rule"]
    scenarios = scen_cfg["management"]
    if a.scenario_ids:
        _keep = a.scenario_ids.split(",")
        scenarios = [s for s in scenarios if s["id"] in _keep]
        assert len(scenarios) == len(_keep), "scenario id not found"
    RECAL = {}
    for _tok in [x for x in a.recal.split(",") if x]:
        _s, _k, _f = _tok.split(":"); RECAL[_s] = (float(_k), float(_f))
    def _arms(st):
        out = []
        for arm in a.arms.split(","):
            if arm == "default":
                out.append(("default", "", 0.0))
            elif arm == "calibrated":
                out.append(("calibrated", cal_kw, 0.0))
            elif arm == "recal":
                ks, fa = RECAL[st]
                out.append(("recal", modkw(cal_kw, kB=1.0, PL=a.recal_pl, PU=a.recal_pu, kS=ks), fa))
            else:
                raise ValueError(arm)
        return out
    for _s, (_k, _f) in RECAL.items():
        _b = modkw(cal_kw, kB=1.0, PL=a.recal_pl, PU=a.recal_pu, kS=_k)
        (outdir / f"s41cf-recal-keywords-{_s}.txt").write_text(_b + "\n" + fixmort_cycles(_f, 5, a.horizon // 5 + 1, 2000) + "\n")
        print(f"S41 recal {_s}: kS {_k} fa {_f} PL {a.recal_pl} PU {a.recal_pu} block md5 {hashlib.md5(_b.encode()).hexdigest()} cycle prop {1-(1-_f)**5:.6f}", flush=True)
    print(f"S41 scenarios {[s['id'] for s in scenarios]} arms {a.arms}", flush=True)

    jobs = []
    stand_meta = []
    res_rows: list[dict] = []
    sample_res: dict[str, dict] = {}
    sample_res_ft: dict[tuple, dict] = {}
    sid = 0
    for st in a.states.split(","):
        cond, trees = extract_state(fia_dir, st, log)
        tg = {k: v for k, v in trees.groupby(trees["PLT_CN"].astype("int64"))}
        cand = []
        pool_res = new_res_counter()
        pool_res_ft: dict[int, dict] = {}
        n_gate_extra = 0
        for _, c in cond.iterrows():
            pc = int(c["PLT_CN"])
            t = tg.get(pc)
            if t is None or len(t) < 5:
                continue
            alphas, stages = resolve_stems(ik, t["SPCD"])
            n_fiajsp = int((stages == "fiajsp").sum())
            n_resolved = int(alphas.notna().sum())
            gate_ok = (n_fiajsp >= 5) if a.frame_gate == "fiajsp" else (n_resolved >= 5)
            if n_resolved >= 5 and n_fiajsp < 5:
                n_gate_extra += 1
            if not gate_ok:
                continue
            g = int((c["FORTYPCD"] or 999) // 10) * 10
            add_res(pool_res, alphas, stages, t["SPCD"])
            add_res(pool_res_ft.setdefault(g, new_res_counter()), alphas,
                    stages, t["SPCD"])
            # every usable stem goes forward; the module resolves them
            cand.append((c, t))
        log.append(f"{st}: {len(cand)} candidate stands under the "
                   f"'{a.frame_gate}' frame gate; {n_gate_extra} stands have "
                   f">=5 resolvable stems but <5 FIAJSP-mapped stems and are "
                   f"{'admitted' if a.frame_gate == 'resolved' else 'excluded (so the 2026-09-04 draw reproduces)'}")
        log.append(fmt_res(f"{st} candidate pool species resolution", pool_res))
        for g in sorted(pool_res_ft):
            log.append(fmt_res(f"{st} pool FORTYPCD group {g}", pool_res_ft[g]))
        res_rows.extend(res_to_rows(st, "candidate_pool", "all", pool_res))
        for g in sorted(pool_res_ft):
            res_rows.extend(res_to_rows(st, "candidate_pool", str(g), pool_res_ft[g]))

        # Stratified sample by forest-type group so the draw is not
        # dominated by whichever type happens to be most numerous.
        by_ft: dict[int, list] = {}
        for c, t in cand:
            g = int((c["FORTYPCD"] or 999) // 10) * 10
            by_ft.setdefault(g, []).append((c, t))
        target = min(a.n_per_state, len(cand))
        picked = []
        groups = sorted(by_ft.keys())
        for g in groups:
            share = max(1, round(target * len(by_ft[g]) / len(cand)))
            pool = by_ft[g]
            random.shuffle(pool)
            picked.extend(pool[:share])
        random.shuffle(picked)
        picked = picked[:target]
        log.append(f"{st}: sampled {len(picked)} stands across "
                   f"{len(groups)} forest-type groups (seed {a.seed})")

        for c, t in picked:
            sid += 1
            alphas, stages = resolve_stems(ik, t["SPCD"])
            add_res(sample_res.setdefault(st, new_res_counter()), alphas,
                    stages, t["SPCD"])
            g = int((c["FORTYPCD"] or 999) // 10) * 10
            add_res(sample_res_ft.setdefault((st, g), new_res_counter()),
                    alphas, stages, t["SPCD"])
            # Opaque stand identifier. No PLT_CN, no coordinate, nothing
            # joinable to one, ever leaves this function.
            stand_id = f"{st}{sid:06d}"
            elev = c.get("ELEV")
            elev = 1000.0 if pd.isna(elev) else float(elev) * 1.0
            slope = c.get("SLOPE")
            aspect = c.get("ASPECT")
            stand = {
                "site_index": float(c["SICOND"]),
                "age": float(c["STDAGE"]),
                "aspect": 0.0 if pd.isna(aspect) else float(aspect),
                "slope": 15.0 if pd.isna(slope) else float(slope),
                "elevft": elev,
                "forest_type": int(c["FORTYPCD"]) if not pd.isna(
                    c["FORTYPCD"]) else 901,
                "inv_year": int(c["MEASYEAR"]) if not pd.isna(
                    c.get("MEASYEAR")) else int(c["INVYR"]),
            }
            tr = [{"species": int(r.SPCD), "diameter": float(r.DIA),
                   "ht": float(r.HT), "crratio": float(r.CR),
                   "tree_count": float(r.TPA_UNADJ)}
                  for r in t.itertuples()]
            regime = owner_regime(c.get("OWNGRPCD"))
            stand_meta.append({
                "stand_id": stand_id, "state": st, "regime": regime,
                "inv_year": stand["inv_year"], "age0": stand["age"],
                "site_index_ft": stand["site_index"],
                "fortypcd": stand["forest_type"], "n_trees": len(tr),
                "n_trees_fiajsp": int((stages == "fiajsp").sum()),
                "n_trees_spctrn": int((stages == "spctrn").sum()),
                "n_trees_other": int((stages == "other").sum()),
                "n_trees_rn": int((alphas == "RN").sum()),
            })
            for scen in scenarios:
                hy, f, note = harvest_years(scen, regimes, rule, regime,
                                            a.horizon)
                for arm, kwb, fa in _arms(st):
                    jobs.append({
                        "stand_id": stand_id, "state": st,
                        "scenario": scen["id"], "arm": arm,
                        "regime": regime, "stand": stand, "trees": tr,
                        "harvest_offsets": hy, "removal_fraction": f,
                        "cal_keywords": kwb, "fixmort_fa": fa,
                        # One cycle beyond the reporting horizon. The FFE
                        # STAND CARBON REPORT prints at the START of each
                        # cycle, so it omits the last cycle's end year; with
                        # horizon/5 cycles exactly, year 50 carries basal area
                        # and volume but no carbon. Established empirically on
                        # the Northeast run, not assumed. The extra cycle is
                        # projected and discarded.
                        "num_cycles": a.horizon // 5 + 1,
                        "fvs_modern": str(fvs_modern),
                        "fvs_bin": str(Path(a.fvs_bin).expanduser()),
                        "scratch": a.scratch,
                    })

    for st in sample_res:
        log.append(fmt_res(f"{st} SAMPLED stands species resolution", sample_res[st]))
        res_rows.extend(res_to_rows(st, "sampled", "all", sample_res[st]))
    for (st, g) in sorted(sample_res_ft):
        log.append(fmt_res(f"{st} sampled FORTYPCD group {g}", sample_res_ft[(st, g)]))
        res_rows.extend(res_to_rows(st, "sampled", str(g), sample_res_ft[(st, g)]))
    log.append(f"total FVS runs queued: {len(jobs)} "
               f"({len(stand_meta)} stands x {len(scenarios)} scenarios x 2 arms)")
    print("\n".join(log), flush=True)

    traj = []
    failed = []
    done = 0
    worker_res = new_res_counter()
    with ProcessPoolExecutor(max_workers=a.workers) as ex:
        futs = [ex.submit(run_one, j) for j in jobs]
        for fu in as_completed(futs):
            r = fu.result()
            done += 1
            if done % 1000 == 0:
                print(f"  {done}/{len(jobs)} runs complete", flush=True)
            if not r.get("ok"):
                failed.append({"stand_id": r["stand_id"],
                               "reason": r.get("reason")})
                continue
            if r["scenario"] == scenarios[0]["id"] and r["arm"] == "default":
                wc = r["res_counts"]
                worker_res["stands"] += wc["stands"]
                for k in ("total_stems", "fiajsp_stems", "spctrn_stems",
                          "other_stems", "dropped_stems"):
                    worker_res[k] += wc[k]
                worker_res["spctrn_by_spcd"].update(wc["spctrn_by_spcd"])
            base_year = r["rows"][0]["year"]
            for row in r["rows"]:
                rec = {
                    "stand_id": r["stand_id"], "state": r["state"],
                    "scenario": r["scenario"], "arm": r["arm"],
                    "owner_regime": r["regime"],
                    "climate_id": "not_modeled",
                    "inv_year": r["inv_year"],
                    "year_offset": int(row["year"] - base_year),
                    "calendar_year": int(row["year"]),
                    "stand_age": row["age"],
                    "site_index_ft": r["site_index"],
                    "fortypcd": r["fortypcd"],
                }
                rec.update(row)
                rec["ba_m2ha"] = row["ba"] * FT2AC_TO_M2HA
                rec["qmd_cm"] = row["qmd"] * IN_TO_CM
                rec["tph"] = row["tpa"] * PERAC_TO_PERHA
                rec["topht_m"] = row["topht"] * FT_TO_M
                rec["tot_vol_m3ha"] = row["tot_cuft"] * FT3AC_TO_M3HA
                rec["merch_vol_m3ha"] = row["merch_cuft"] * FT3AC_TO_M3HA
                rec["rem_vol_m3ha"] = row["rem_tot_cuft"] * FT3AC_TO_M3HA
                cb = r.get("carbon", {}).get(int(row["year"]))
                if cb:
                    rec["c_abg_live_MgCha"] = (
                        cb["c_abg_live_tonac"] * TONAC_TO_MGHA)
                    rec["c_total_stand_MgCha"] = (
                        cb["c_total_stand_tonac"] * TONAC_TO_MGHA)
                    rec["c_removed_MgCha"] = (
                        cb["c_total_removed_tonac"] * TONAC_TO_MGHA)
                else:
                    rec["c_abg_live_MgCha"] = None
                    rec["c_total_stand_MgCha"] = None
                    rec["c_removed_MgCha"] = None
                traj.append(rec)

    # Cross-check: the module's own counters, summed over one run per stand,
    # must equal the main-process count over the sampled stands.
    main_tot = {k: sum(v[k] for v in sample_res.values())
                for k in ("stands", "total_stems", "fiajsp_stems",
                          "spctrn_stems", "other_stems", "dropped_stems")}
    wk_tot = {k: worker_res[k] for k in main_tot}
    log.append(f"module counters (make_inventory_keyfile, one run per stand): "
               f"{wk_tot}; main-process count over sampled stands: {main_tot}; "
               f"agree {wk_tot == main_tot}")
    if wk_tot != main_tot:
        raise RuntimeError("species resolution counts disagree between the "
                           "module and the main process; refusing to write.")

    tdf = pd.DataFrame(traj)
    # Drop the extra carbon-report cycle so no row past the stated 50-year
    # horizon appears in any deliverable.
    tdf = tdf[tdf["year_offset"] <= a.horizon]
    d = a.s41_out_date
    safe_to_csv(tdf, outdir / f"fvs-ls-stand-trajectories_DATA_{d}.csv")
    safe_to_csv(pd.DataFrame(stand_meta),
                outdir / f"fvs-ls-stand-inventory_DATA_{d}.csv")
    safe_to_csv(pd.DataFrame(res_rows),
                outdir / f"fvs-ls-species-resolution_DATA_{d}.csv")
    if failed:
        safe_to_csv(pd.DataFrame(failed),
                    outdir / f"fvs-ls-failed-runs_DATA_{d}.csv")

    # State-level summary at 0, 25 and 50 years from inventory
    keep_off = [0, 25, a.horizon]
    s = tdf[tdf["year_offset"].isin(keep_off)]
    grp = s.groupby(["state", "scenario", "arm", "year_offset"])
    summ = grp.agg(
        n_stands=("stand_id", "nunique"),
        mean_stand_age=("stand_age", "mean"),
        mean_site_index_ft=("site_index_ft", "mean"),
        mean_tpa=("tpa", "mean"),
        mean_tph=("tph", "mean"),
        mean_ba_ft2ac=("ba", "mean"),
        mean_ba_m2ha=("ba_m2ha", "mean"),
        mean_qmd_in=("qmd", "mean"),
        mean_qmd_cm=("qmd_cm", "mean"),
        mean_topht_ft=("topht", "mean"),
        mean_topht_m=("topht_m", "mean"),
        mean_sdi=("sdi", "mean"),
        mean_tot_cuft_ac=("tot_cuft", "mean"),
        mean_tot_vol_m3ha=("tot_vol_m3ha", "mean"),
        mean_merch_cuft_ac=("merch_cuft", "mean"),
        mean_merch_vol_m3ha=("merch_vol_m3ha", "mean"),
        mean_c_abg_live_MgCha=("c_abg_live_MgCha", "mean"),
        mean_c_total_stand_MgCha=("c_total_stand_MgCha", "mean"),
        n_carbon=("c_abg_live_MgCha", "count"),
    ).reset_index()

    # cumulative removals over the whole horizon, per stand then averaged
    rem = (tdf.groupby(["state", "scenario", "arm", "stand_id"])
              .agg(rem_cuft=("rem_tot_cuft", "sum"),
                   rem_m3ha=("rem_vol_m3ha", "sum"),
                   n_entries=("rem_tpa", lambda x: int((x > 0).sum())))
              .reset_index()
              .groupby(["state", "scenario", "arm"])
              .agg(mean_cum_removed_cuft_ac=("rem_cuft", "mean"),
                   mean_cum_removed_m3ha=("rem_m3ha", "mean"),
                   mean_harvest_entries=("n_entries", "mean"))
              .reset_index())
    summ = summ.merge(rem, on=["state", "scenario", "arm"], how="left")
    summ["climate_id"] = "not_modeled"
    summ["pathway"] = "FVS-LS"
    summ["horizon_years"] = a.horizon

    # The three structural moments below are averaged INDEPENDENTLY across
    # stands and are therefore not internally consistent with one another.
    # This is the identical defect that reversed the sign of the first OSM
    # Northeast carbon number, so the file carries the diagnostic explicitly
    # rather than leaving the next reader to discover it. Carbon in this file
    # is computed per stand by FFE and averaged afterwards, so it never passes
    # through these means and is unaffected.
    implied = (summ["mean_tph"] * 3.14159265358979 / 4.0
               * (summ["mean_qmd_cm"] / 100.0) ** 2)
    summ["implied_ba_m2ha_from_means"] = implied
    summ["rel_BA_consistency_error"] = (
        (implied - summ["mean_ba_m2ha"]) / summ["mean_ba_m2ha"])
    summ["moment_consistency_warning"] = (
        "mean_ba_m2ha, mean_qmd_cm and mean_tph are independent averages; "
        "do not apply an allometry to them, use the stand trajectories file")

    safe_to_csv(summ, outdir / f"fvs-ls-state-summary_DATA_{d}.csv")

    (outdir / f"fvs-ls-run-log_DATA_{d}.txt").write_text(
        "\n".join(log) + f"\n\nfailed runs: {len(failed)} of {len(jobs)}\n")
    print("\n".join(log))
    print(f"failed runs: {len(failed)} of {len(jobs)}")
    print(summ.to_string(index=False))


if __name__ == "__main__":
    main()
