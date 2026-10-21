#!/usr/bin/env python3
"""
FVS Northeast (variant NE) state-scope runner, NCASI Model Evaluation Phase II.

RERUN OF 2026-09-07 (this file). The 2026-09-04 runner is left untouched.
  WHY. The September 4 and 6 runs pre-translated FIA SPCD to FVS alpha
  codes through the variant's FIAJSP table only (the 107 entry crosswalk
  read out of ne.json) and pre-filtered anything that table did not
  cover. That bypasses the second stage of FVS's own species resolution,
  SPCTRN in src-converted/vls/spctrn.f90 (562 rows, NE target column),
  which base/intree.f90 calls whenever FIAJSP misses, and after which
  any code with no row at all lands on the variant's "other hardwood"
  slot OH. In the Northeast this was judged harmless because the NE
  FIAJSP table is keyed by species codes and the dropped share was 0.44
  to 1.06 percent of stems. Aaron decided (September 7, 2026) to rerun
  all three regions on the engine faithful crosswalk for uniform
  provenance. The expectation for NE is that the numbers barely move;
  this run measures that rather than assuming it.
  WHAT CHANGED, and nothing else.
    (a) make_inventory_keyfile() is called with use_spctrn=True and
        spctrn_other_fallback=True on the module patched 2026-09-07
        (md5 4804454a8aff48e948f659965fd597ee, printed in the log with
        SPCTRN_ROW_COUNT), so resolution is FIAJSP, then SPCTRN, then OH,
        exactly as intree.f90 does. Nothing is dropped and nothing is
        relabelled outside that table.
    (b) The two in-memory overrides of the 2026-09-04 runner are
        REDUNDANT and removed: the patched module's FIA_TO_FVS_SP["ne"]
        is the full 107 entry ne.json crosswalk and its
        STDINFO_DEFAULTS["ne"] is location 919. Both facts are ASSERTED
        at start-up against ne.json and the module (the run refuses to
        start if either differs), so removing the overrides changes no
        input.
    (c) FRAME GATE, 2026-09-07b amendment. The 2026-09-07 run kept the
        candidate gate at "at least 5 FIAJSP mapped live trees",
        deliberately, so the candidate pool, the stratified draw under
        seed 20260904 and the stand ids were byte identical to the
        2026-09-04 run and the SPCTRN effect was isolated from any
        sample frame change. Aaron decided (September 7, 2026, second
        pass) that the deliverable runs on the engine faithful frame, so
        this file adds --frame-gate. With --frame-gate resolved the gate
        becomes "at least 5 stems that FVS itself can resolve", which is
        eligibility computed AFTER FIAJSP, SPCTRN and the OH other slot,
        exactly the frame the engine would see. That admits stands the
        narrow gate excluded, mostly nonstocked and hardwood scrub types,
        and it BREAKS the pairing with the 2026-09-04 draw because the
        candidate list feeds the seeded stratified shuffle. The default
        stays fiajsp so the September 7 run reproduces from this file.
        The additionally admitted stands are counted, tabulated by
        forest type and written to fvs-ne-frame-gate-extra_DATA_*.csv.
        Original note kept for the record: the narrow gate isolated the
        SPCTRN effect from any sample frame change, and it is verified
        after sampling against the 2026-09-04 stand inventory when
        --prior-inventory is given. Under --frame-gate resolved that
        identity check is advisory rather than enforcing, since the draw
        is expected to differ.
        What changed is that every live usable stem in a sampled stand
        now reaches the keyfile builder; stems the old pre-filter
        dropped are resolved through SPCTRN or OH.
    (d) The engine is the v1 release binary
        ~/fvs-modern/bin-v1_20260906/FVSne (built from 895f5aa), the
        same one the September 6 v1 rerun used, so the comparison of
        record is against out_v1_20260906/ (same binary, FIAJSP only)
        and the SPCTRN effect is the only difference. The workspace
        2026-09-04 summary is on the July 15 binary and differs for
        engine reasons already recorded in MEMORY.md.
  WHAT IS LOGGED IN ADDITION.
    Species resolution counts per state (candidate pool and sampled
    stands) and per sampled forest type group: total, via FIAJSP, via
    SPCTRN, to OH, dropped, plus the SPCD tallies behind the SPCTRN
    and OH stems. The ne.json actually loaded (path, size, mtime, md5,
    calibration date). The calibrated keyword inventory: per keyword
    the record count, multiplier range and how many records differ
    from unity or, for SDIMAX, from the compiled sitset.f90 SDICON
    defaults, plus per state the stem and basal area share of sampled
    stems whose species carries each live keyword, so the narrower NE
    calibrated contrast can be explained by measurement later.

Adds FVS as the THIRD pathway for the Northeast region, alongside the
FIA/TreeMap space-for-time yield curves (pathway 1) and OSM (pathway 2).
Runs at STATE scope, following the precedent set by the OSM, GLFPS and
PMRC first passes, because the management-area polygon layer that
mgmt-area/ma_00_define_units.R requires does not exist for any region
yet (cooperator selection, Section 3.4 of the implementation plan, still
open). This is NOT a management-area run and must not be reported as one.

STATES: ME, NH, VT, NY.
  New York IS included, unlike the OSM pathway. OSM was left unbuilt for
  NY because OSM's calibration domain is ME/NB/NS/PEI and has no coverage
  west of Maine. FVS-NE carries no such restriction: the compiled NE
  variant is the production variant for New York, and prior work in this
  workspace has already run NY FIA plots under NE (see fvs-modern
  docs/archive/SESSION_HANDOFF_acd-bridge-fix-2026-05-15.md, "1736 NY
  Adirondack" plots inside a 14,717-plot NE retention). A separate ADK
  (Adirondack) variant exists in fvs-modern/src-converted/adk but is
  scaffolded from Acadian and explicitly NOT calibrated
  (docs/program/20260618_adk_variant_status.md), so it is not used here.

WHAT THIS REUSES RATHER THAN REBUILDS
  - repos/fvs-modern/calibration/python/inventory_keyfile.py, imported
    unmodified. All five keyfile bugs fixed 2026-08-27 and smoke-verified
    for PN/SN are present in the file this script imports and were
    re-verified before use: (1) TREEFMT emitted as supplemental records /
    dropped in favour of the default layout, (2) TREEDATA carries 15 so
    inline records are read, (3) tree record variable order matches
    base/intree.f90's default, (4) STDINFO field 3 carries age with site
    index moved to a SITECODE keyword, (5) DESIGN is a per-acre fixed
    plot rather than a BAF-40 prism (which inflated TPA ~9x).
  - repos/fvs-modern/config/config_loader.py FvsConfigLoader, for the
    calibrated keyword block. No calibration coefficient is written here.
  - mgmt-area/ma_06_scenarios.yml, for the five management scenarios and
    the owner-regime scaling rule. No new rotation length, entry interval
    or removal fraction is introduced.

TWO IN-MEMORY OVERRIDES OF inventory_keyfile.py IN THE 2026-09-04 RUNNER,
both now redundant against the patched module and REMOVED in this file
(see the RERUN note above; the text below is kept as the record of why
they existed):
  1. FIA_TO_FVS_SP["ne"] in that module carries only 13 species and is
     labelled "eastern fallback, kept for API symmetry". Its
     fia_to_fvs_code() silently falls back to the FIRST species in the
     table on any unmapped SPCD, which on real FIA data would silently
     relabel species. This script replaces that table with the full
     108-species crosswalk read out of config/calibrated/ne.json
     (species_definitions.FIAJSP -> species_definitions.JSP), which is
     the variant's own authoritative mapping, AND pre-filters trees to
     mapped SPCDs so the fallback can never fire. Unmapped stems are
     counted and reported, never relabelled.
  2. STDINFO_DEFAULTS["ne"]["forest"] is 902, commented "White Mountain
     NF". 902 is not a valid FVS-NE location code: ne/blkdat.f90 line 108
     sets IFORCD/911,919,920,921,922,15*0/, and the White Mountain NF code
     in that list is 919, not 902. This is a real (small) defect in the
     committed file, reported rather than patched in place. This script
     uses 919 for every stand in all four states, a single constant so no
     cross-state artefact is introduced by the location code itself.
     OCURNF in ne/blkdat.f90 is all 1.0, so the location code performs no
     species zeroing in this variant; its effect is confined to volume
     equation selection in sitset.f90.

CLIMATE: not modelled, and this was checked rather than assumed. The only
"climate" tokens anywhere in the NE growth kernels are in dgf.f90 line 120
and htgf.f90 line 93, both guarded no-ops unless FVS_GREGDG / FVS_GREGHG
are set. This script unsets both. Every row is tagged
climate_id = not_modeled, the same honest tag ma_07_glfps_build.R uses,
rather than emitting duplicate identical rows under rcp45 and rcp85
labels that would read downstream as false climate sensitivity.

OWNERSHIP: FIA condition-level OWNCD/OWNGRPCD cannot separate Industrial
from NIPF (confirmed directly against Georgia's COND table 2026-09-04:
55,988 of ~62,000 non-blank private conditions sit in a single
undifferentiated OWNCD 46 Corporate bucket). The clearcut owner regime in
ma_06_scenarios.yml therefore never fires here, exactly as it did not
fire for OSM, GLFPS or PMRC. Every harvest event in this run is a partial
proportional removal. This is a data-availability gap, stated, not worked
around.

REGENERATION: no post-clearcut regeneration is simulated. FVS-NE has a
regeneration routine (ne/regent.f90) but this project holds no documented,
sourced regeneration parameterisation for these stands, and Premer's own
Great Lakes memo flags his FVS-LS regeneration cohort as a stated
assumption rather than a modelled process. Since the clearcut branch never
fires anyway (see OWNERSHIP), nothing is truncated in this run, but the
gap is recorded so it is not discovered later.

FIA TRUE COORDINATES: never read. This script opens <ST>_COND.csv,
<ST>_TREE.csv and <ST>_PLOT.csv only, and for PLOT.csv restricts usecols
to CN, ELEV and MEASYEAR. LAT, LON, and every fuzzed or unfuzzed
coordinate column is excluded at read time, so no coordinate is ever
materialised in memory, let alone written. No output carries PLT_CN
either; stands are keyed by an opaque sequential id.

Usage (Cardinal, 2026-09-07 rerun):
  python3 fvs_ne_state_scope_runner_DRAFT_2026-09-07.py \
      --fia-dir ~/fia_data \
      --fvs-modern /fs/scratch/PUOM0008/crsfaaron/v1tag_20260811 \
      --keyfile-module-dir ~/fvs-modern/calibration/python \
      --fvs-bin ~/fvs-modern/bin-v1_20260906/FVSne \
      --scenarios ~/ncasi_fvsne/ma_06_scenarios.yml \
      --outdir ~/ncasi_fvsne/out_20260907 \
      --prior-inventory ~/ncasi_fvsne/out_v1_20260906/fvs-ne-stand-inventory_DATA_2026-09-04.csv \
      --states ME,NH,VT,NY --n-per-state 300 --workers 24 --seed 20260904
  --fvs-modern is the config tree (FvsConfigLoader and ne.json), the same
  v1 tag tree the September 6 v1 rerun used; --keyfile-module-dir is
  where the PATCHED inventory_keyfile.py lives, which is a different
  checkout. The two are separated on purpose so the calibration inputs
  stay identical to the v1 rerun while the crosswalk comes from the
  patched module.

Author: NCASI Model Evaluation Phase II working session
Date: 2026-09-04; rerun file 2026-09-07; frame-gate file 2026-09-07b
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import pandas as pd
import yaml

# --------------------------------------------------------------------------
# Unit conversions. Exact definitional factors only; no allometry, no fitted
# relationship, nothing derived. These are here so the Northeast FVS arm can
# be read against the SI-reported GLFPS and OSM arms without anyone having to
# redo the arithmetic downstream.
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

STATE_FIPS = {"ME": 23, "NH": 33, "VT": 50, "NY": 36}

# FVS-NE location code. 919 = White Mountain NF, one of the five codes in
# ne/blkdat.f90 IFORCD. See module docstring for why not 902.
NE_FOREST_CODE = 919

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

SUMMARY_FIELDS = [
    "year", "age", "tpa", "ba", "sdi", "ccf", "topht", "qmd",
    "tot_cuft", "merch_cuft", "sawlg_cuft", "merch_bdft",
    "rem_tpa", "rem_tot_cuft", "rem_merch_cuft", "rem_sawlg_cuft",
    "rem_merch_bdft",
    "res_ba", "res_sdi", "res_ccf", "res_topht", "res_qmd",
    "period_years", "accretion", "mortality", "mai_merch_cuft",
]


# --------------------------------------------------------------------------
# Species crosswalk, read from the variant's own calibrated JSON
# --------------------------------------------------------------------------
def load_ne_species_crosswalk(fvs_modern: Path) -> dict[int, str]:
    """FIA SPCD -> FVS-NE two-letter alpha code, from ne.json.

    species_definitions.FIAJSP[i] is the FIA species code for NE species
    index i+1 and .JSP[i] is that species' FVS alpha code. This is the
    variant's own mapping as extracted from blkdat.f90, not a hand-built
    table. Index 71 is a blank placeholder in the variant and is skipped.
    """
    cfg = json.loads((fvs_modern / "config" / "calibrated" / "ne.json").read_text())
    sd = cfg["categories"]["species_definitions"]
    out: dict[int, str] = {}
    for alpha, fia in zip(sd["JSP"], sd["FIAJSP"]):
        a = str(alpha).strip()
        f = str(fia).strip()
        if not a or not f:
            continue
        try:
            out[int(f)] = a
        except ValueError:
            continue
    if len(out) < 100:
        raise RuntimeError(
            f"NE species crosswalk built only {len(out)} entries from ne.json; "
            "expected ~107. Refusing to run on a truncated crosswalk."
        )
    return out


def load_calibrated_keywords(fvs_modern: Path) -> str:
    """Calibrated FVS-NE keyword block via the repo's own config loader.

    Returns the block and a short manifest of what it actually contains, so
    the calibrated-versus-default contrast can be described honestly rather
    than assumed to cover every component the JSON names.
    """
    sys.path.insert(0, str(fvs_modern))
    from config.config_loader import FvsConfigLoader  # noqa: E402
    loader = FvsConfigLoader("ne", version="calibrated",
                             config_dir=str(fvs_modern / "config"))
    return loader.generate_keywords(include_comments=False)


def describe_keywords(block: str) -> dict:
    counts: dict[str, int] = {}
    for line in block.splitlines():
        kw = line.split()[0] if line.split() else ""
        if kw:
            counts[kw] = counts.get(kw, 0) + 1
    return counts


def _md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def load_ne_species_index(fvs_modern: Path) -> dict[str, int]:
    """FVS-NE alpha code -> 1-based species index, from ne.json JSP order."""
    cfg = json.loads((fvs_modern / "config" / "calibrated" / "ne.json").read_text())
    jsp = cfg["categories"]["species_definitions"]["JSP"]
    return {str(a).strip(): i + 1 for i, a in enumerate(jsp) if str(a).strip()}


def load_sdicon(fvs_modern: Path) -> list[float]:
    """Compiled SDIMAX defaults, DATA SDICON in ne/sitset.f90 (MAXSP=108).

    sitset.f90 sets SDIDEF(I) = SDICON(I) for every species whose SDIMAX
    was not set by keyword and BAMAX is not set, so SDICON is the exact
    default the SDIMAX keyword records are measured against.
    """
    src = (fvs_modern / "src-converted" / "ne" / "sitset.f90").read_text().splitlines()
    i0 = next(k for k, l in enumerate(src) if l.strip().startswith("DATA SDICON"))
    vals: list[float] = []
    for l in src[i0:]:
        body = l.split("/")[-1] if l.strip().startswith("DATA") else l
        body = body.replace("&", "").replace("/", "")
        for tok in body.split(","):
            tok = tok.strip()
            if tok:
                vals.append(float(tok))
        if "/" in l and not l.strip().startswith("DATA"):
            break
    if len(vals) != 108:
        raise RuntimeError(f"parsed {len(vals)} SDICON values, expected 108")
    return vals


def parse_keyword_block(block: str) -> dict[str, dict[int, float]]:
    """{keyword: {species_index: value}} from the emitted calibrated block.

    SDIMAX and BAIMULT lines are 'KW idx value'; MORTMULT lines are
    'KW idx value dbh_lo dbh_hi' with the multiplier in field 3.
    """
    out: dict[str, dict[int, float]] = {}
    for line in block.splitlines():
        p = line.split()
        if len(p) < 3:
            continue
        try:
            idx = int(p[1])
            val = float(p[2])
        except ValueError:
            continue
        out.setdefault(p[0], {})[idx] = val
    return out


def keyword_inventory(block: str, sdicon: list[float]) -> tuple[list[str], dict]:
    """Log lines and a machine-readable dict describing which calibration
    keywords are live and by how much. Per keyword: record count, min,
    max, mean, records differing from the reference by more than 0.5
    percent (unity for multipliers, SDICON for SDIMAX), and for SDIMAX
    the mean ratio to the compiled default."""
    kwv = parse_keyword_block(block)
    lines = []
    info: dict = {}
    for kw, d in sorted(kwv.items()):
        vals = list(d.values())
        if kw == "SDIMAX":
            ratios = {i: v / sdicon[i - 1] for i, v in d.items() if sdicon[i - 1] > 0}
            ndiff = sum(1 for r in ratios.values() if abs(r - 1.0) > 0.005)
            mr = sum(ratios.values()) / len(ratios)
            lines.append(
                f"keyword {kw}: {len(d)} records, values {min(vals):.0f} to "
                f"{max(vals):.0f}, {ndiff} of {len(d)} differ from the compiled "
                f"sitset.f90 SDICON default by more than 0.5 percent, ratio to "
                f"default {min(ratios.values()):.3f} to {max(ratios.values()):.3f}, "
                f"mean {mr:.3f}; LIVE" if ndiff else
                f"keyword {kw}: {len(d)} records, all equal to the compiled "
                f"SDICON defaults; INERT")
            info[kw] = dict(n=len(d), vmin=min(vals), vmax=max(vals),
                            n_differ_from_default=ndiff,
                            ratio_min=min(ratios.values()),
                            ratio_max=max(ratios.values()), ratio_mean=mr,
                            live=bool(ndiff), per_species=ratios)
        else:
            ndiff = sum(1 for v in vals if abs(v - 1.0) > 0.005)
            lines.append(
                f"keyword {kw}: {len(d)} records, multiplier {min(vals):.4f} to "
                f"{max(vals):.4f}, mean {sum(vals)/len(vals):.4f}, {ndiff} of "
                f"{len(d)} differ from unity by more than 0.5 percent; "
                f"{'LIVE' if ndiff else 'INERT'}")
            info[kw] = dict(n=len(d), vmin=min(vals), vmax=max(vals),
                            mean=sum(vals) / len(vals),
                            n_differ_from_default=ndiff, live=bool(ndiff),
                            per_species=dict(d))
    absent = [k for k in ("HTGMULT", "READCORD", "REGDMULT", "MORTMULT",
                          "BAIMULT", "SDIMAX", "BAMAX", "FIXMORT")
              if k not in kwv]
    lines.append(f"keywords with no record in the emitted block: {absent}")
    return lines, info


def keyword_exposure_by_state(stems: list[dict], kwinfo: dict,
                              sp_index: dict[str, int]) -> list[str]:
    """Per state, the share of sampled stems and of their basal area whose
    resolved species carries a live record for each keyword, and the
    stem and BA weighted mean multiplier (or SDIMAX ratio to default)
    over those stems. stems is a list of {state, alpha, tpa, ba_ft2ac}.
    The keyword block itself is one file for the whole variant, so the
    per state differences here come only from species composition."""
    out = []
    by_state: dict[str, list[dict]] = {}
    for s in stems:
        by_state.setdefault(s["state"], []).append(s)
    for st, rows in sorted(by_state.items()):
        tot_n = sum(r["tpa"] for r in rows)
        tot_ba = sum(r["ba"] for r in rows)
        for kw, inf in sorted(kwinfo.items()):
            per = inf["per_species"]
            live_idx = {i for i, v in per.items() if abs(v - 1.0) > 0.005}
            n_live = ba_live = wsum_n = wsum_ba = 0.0
            for r in rows:
                i = sp_index.get(r["alpha"])
                if i in live_idx:
                    n_live += r["tpa"]
                    ba_live += r["ba"]
                    wsum_n += r["tpa"] * per[i]
                    wsum_ba += r["ba"] * per[i]
            out.append(
                f"{st} {kw}: live for {100*n_live/tot_n:.1f}% of stems and "
                f"{100*ba_live/tot_ba:.1f}% of basal area; among those the "
                f"stem weighted mean {'ratio to default' if kw=='SDIMAX' else 'multiplier'} "
                f"is {wsum_n/n_live if n_live else float('nan'):.3f} and the BA "
                f"weighted mean is {wsum_ba/ba_live if ba_live else float('nan'):.3f}")
    return out


def resolve_stems(ik, spcds) -> list[tuple]:
    """(alpha, stage) per SPCD through the patched module's two-stage
    lookup with the same options the keyfile builder receives."""
    return [ik.resolve_fvs_code(int(c), "ne", use_spctrn=True,
                                other_fallback=True) for c in spcds]


def tally(resolved: list[tuple], spcds) -> dict:
    c = {"total": len(resolved), "fiajsp": 0, "spctrn": 0, "other": 0,
         "dropped": 0, "spctrn_by_spcd": {}, "other_by_spcd": {},
         "dropped_by_spcd": {}}
    for (alpha, stage), sp in zip(resolved, spcds):
        sp = int(sp)
        if stage is None:
            c["dropped"] += 1
            c["dropped_by_spcd"][sp] = c["dropped_by_spcd"].get(sp, 0) + 1
        else:
            c[stage] += 1
            if stage == "spctrn":
                c["spctrn_by_spcd"][sp] = c["spctrn_by_spcd"].get(sp, 0) + 1
            elif stage == "other":
                c["other_by_spcd"][sp] = c["other_by_spcd"].get(sp, 0) + 1
    return c


def merge_tally(a: dict, b: dict) -> dict:
    for k in ("total", "fiajsp", "spctrn", "other", "dropped"):
        a[k] = a.get(k, 0) + b[k]
    for k in ("spctrn_by_spcd", "other_by_spcd", "dropped_by_spcd"):
        d = a.setdefault(k, {})
        for sp, n in b[k].items():
            d[sp] = d.get(sp, 0) + n
    return a


def fmt_tally(label: str, c: dict) -> str:
    n = c["total"] or 1
    top = sorted(c["spctrn_by_spcd"].items(), key=lambda x: -x[1])[:8]
    oth = sorted(c["other_by_spcd"].items(), key=lambda x: -x[1])[:5]
    return (f"{label}: {c['total']} stems, {c['fiajsp']} via FIAJSP "
            f"({100*c['fiajsp']/n:.2f}%), {c['spctrn']} via SPCTRN "
            f"({100*c['spctrn']/n:.2f}%), {c['other']} to OH other slot "
            f"({100*c['other']/n:.2f}%), {c['dropped']} dropped "
            f"({100*c['dropped']/n:.2f}%); SPCTRN top SPCD {top}; OH top SPCD {oth}")


# --------------------------------------------------------------------------
# FIA extraction
# --------------------------------------------------------------------------
def extract_state(fia_dir: Path, st: str, log: list[str]):
    """Return (stands DataFrame, trees DataFrame) for one state.

    Stand selection rules, all stated rather than implicit:
      - COND_STATUS_CD == 1 (accessible forest land)
      - CONDPROP_UNADJ >= 0.95, so the plot's tree list represents
        essentially the whole plot and a per-acre expansion is meaningful
      - STDAGE > 0 (FVS STDINFO needs a real stand age)
      - SICOND > 0 and SIBASE == 50. SIBASE is ENFORCED, not assumed, the
        same discipline ma_07_glfps_build.R applies: FVS-NE site index is
        base age 50 and no documented conversion exists from another base
        for these curves, so a stand on another base is skipped and logged.
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
    module docstring. This is the same choice OSM and GLFPS made.
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
    from Fire. All in short tons per acre.

    Only Aboveground Live Total and Total Stand Carbon are carried forward.
    Aboveground Live Total is the quantity that corresponds to the FIA and
    TreeMap baseline's aboveground live carbon, so it is what makes this
    pathway readable against that baseline. Total Removed Carbon is carried
    because it is the harvest-side quantity the managed scenarios need.
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
    """Build a keyfile, run FVSne, parse the summary. Returns a record."""
    sys.path.insert(0, job["fvs_modern"])
    sys.path.insert(0, job["keyfile_module_dir"])
    import inventory_keyfile as ik

    # No in-memory overrides in the 2026-09-07 rerun. main() asserts that
    # the patched module's FIA_TO_FVS_SP["ne"] equals the ne.json crosswalk
    # and that STDINFO_DEFAULTS["ne"]["forest"] == NE_FOREST_CODE before any
    # job is queued, and the worker re-checks the location code cheaply.
    if ik.STDINFO_DEFAULTS["ne"]["forest"] != NE_FOREST_CODE:
        return {"stand_id": job["stand_id"], "ok": False,
                "reason": "module location code is not 919"}
    ik.reset_unmapped_stem_counts()

    stand_df = pd.DataFrame([job["stand"]])
    tree_df = pd.DataFrame(job["trees"])

    kw_lines = []
    # Fire and Fuels Extension carbon report. This is what lets the FVS arm be
    # read against the FIA and TreeMap baseline's aboveground live carbon and
    # against the GLFPS arm's Mg C ha-1, instead of stopping at basal area and
    # cubic volume the way the OSM first pass had to.
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
        variant="ne",
        inv_year=int(job["stand"]["inv_year"]),
        num_cycles=job["num_cycles"],
        calibration_keywords="\n".join(kw_lines),
        use_spctrn=True,
        spctrn_other_fallback=True,
    )
    # The module's own per-call counters, returned so the driver can check
    # them against its independent main-process tally for the same stand.
    rc = ik.get_species_resolution_counts("ne")
    res_counts = {k: int(rc[k]) for k in ("total_stems", "fiajsp_stems",
                                          "spctrn_stems", "other_stems",
                                          "dropped_stems")}

    work = tempfile.mkdtemp(prefix="fvsne_", dir=job["scratch"])
    try:
        kp = Path(work) / "s.key"
        kp.write_text(key)
        env = dict(os.environ)
        # Keep the opt-in Greg DG/HG climate kernels off, so "no climate
        # covariate" stays true for this run.
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
    ap.add_argument("--states", default="ME,NH,VT,NY")
    ap.add_argument("--n-per-state", type=int, default=250)
    ap.add_argument("--horizon", type=int, default=50)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--seed", type=int, default=20260904)
    ap.add_argument("--scratch", default="/tmp")
    ap.add_argument("--keyfile-module-dir", default=None,
                    help="directory holding the PATCHED inventory_keyfile.py; "
                         "defaults to <fvs-modern>/calibration/python")
    ap.add_argument("--prior-inventory", default=None,
                    help="2026-09-04 stand inventory CSV to verify the sampled "
                         "stand set is identical (stand_id, state, inv_year, "
                         "age0, site_index_ft, fortypcd)")
    ap.add_argument("--frame-gate", choices=["fiajsp", "resolved"],
                    default="fiajsp",
                    help="Sample-frame gate. fiajsp (default) keeps the "
                         "2026-09-04 gate of at least 5 FIAJSP mapped live "
                         "stems, so the seeded draw reproduces the same 1200 "
                         "stands; resolved uses the engine-faithful gate of at "
                         "least 5 stems FVS can resolve through FIAJSP, SPCTRN "
                         "or the OH other slot, and breaks the pairing.")
    ap.add_argument("--out-date", default="2026-09-07")
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
    kdir = (Path(a.keyfile_module_dir).expanduser() if a.keyfile_module_dir
            else fvs_modern / "calibration" / "python")

    log: list[str] = []

    # ---- provenance of every input that could move a number ----
    sys.path.insert(0, str(fvs_modern))
    sys.path.insert(0, str(kdir))
    import inventory_keyfile as ik  # noqa: E402
    mod_path = Path(ik.__file__)
    log.append(f"inventory_keyfile.py loaded from {mod_path}, md5 {_md5(mod_path)}, "
               f"SPCTRN_ROW_COUNT {getattr(ik, 'SPCTRN_ROW_COUNT', 'ABSENT')}, "
               f"SPCTRN_SOURCE {getattr(ik, 'SPCTRN_SOURCE', 'ABSENT')} md5 "
               f"{_md5(Path(ik.SPCTRN_SOURCE)) if hasattr(ik, 'SPCTRN_SOURCE') else 'ABSENT'}")
    if not hasattr(ik, "resolve_fvs_code") or not hasattr(ik, "SPCTRN_ROW_COUNT"):
        raise RuntimeError("the imported inventory_keyfile.py is not the 2026-09-07 "
                           "SPCTRN patched module; refusing to run")
    ne_tab = ik.spctrn_table("ne")
    log.append(f"SPCTRN NE column: {len(ne_tab)} FIA codes resolvable to an NE "
               f"species beyond FIAJSP; other slot fallback "
               f"{ik.SPCTRN_OTHER_FALLBACK['ne']}")

    nej = fvs_modern / "config" / "calibrated" / "ne.json"
    cfg = json.loads(nej.read_text())
    log.append(f"ne.json loaded from {nej}, {nej.stat().st_size} bytes, mtime "
               f"{_dt.datetime.fromtimestamp(nej.stat().st_mtime):%Y-%m-%d %H:%M}, "
               f"md5 {_md5(nej)}, calibration date "
               f"{cfg.get('calibration', {}).get('date')}, method "
               f"{cfg.get('calibration', {}).get('method')}")
    fb = Path(a.fvs_bin).expanduser()
    log.append(f"FVS binary {fb}, md5 {_md5(fb)}")

    spmap = load_ne_species_crosswalk(fvs_modern)
    log.append(f"NE species crosswalk: {len(spmap)} FIA SPCD entries from "
               f"config/calibrated/ne.json species_definitions")
    # The two 2026-09-04 overrides are redundant only if these hold.
    if dict(ik.FIA_TO_FVS_SP["ne"]) != spmap:
        raise RuntimeError("patched module FIA_TO_FVS_SP['ne'] differs from the "
                           "ne.json crosswalk; the 2026-09-04 override is NOT "
                           "redundant, refusing to run")
    if ik.STDINFO_DEFAULTS["ne"]["forest"] != NE_FOREST_CODE:
        raise RuntimeError("patched module STDINFO_DEFAULTS['ne'] is not 919")
    log.append("2026-09-04 in-memory overrides verified redundant: module "
               f"FIA_TO_FVS_SP['ne'] == ne.json crosswalk ({len(spmap)} entries) "
               f"and STDINFO_DEFAULTS['ne']['forest'] == {NE_FOREST_CODE}; "
               "neither override is applied in this run")

    cal_kw = load_calibrated_keywords(fvs_modern)
    kwc = describe_keywords(cal_kw)
    log.append(f"calibrated keyword block: {kwc}, md5 "
               f"{hashlib.md5(cal_kw.encode()).hexdigest()}, "
               f"{len(cal_kw.splitlines())} lines")
    sdicon = load_sdicon(fvs_modern)
    kw_lines_log, kwinfo = keyword_inventory(cal_kw, sdicon)
    log.extend(kw_lines_log)
    sp_index = load_ne_species_index(fvs_modern)
    (outdir / f"fvs-ne-calibrated-keywords_DATA_{a.out_date}.txt").write_text(cal_kw)

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
    exposure_stems: list[dict] = []
    res_by_state_pool: dict[str, dict] = {}
    res_by_state_sample: dict[str, dict] = {}
    res_by_ftg: dict[tuple, dict] = {}
    gate_extra_rows: list[dict] = []
    sid = 0
    for st in a.states.split(","):
        cond, trees = extract_state(fia_dir, st, log)
        tg = {k: v for k, v in trees.groupby(trees["PLT_CN"].astype("int64"))}
        cand = []
        n_unmapped_total = 0
        n_gate_extra = 0
        pool_tally: dict = {}
        for _, c in cond.iterrows():
            pc = int(c["PLT_CN"])
            t = tg.get(pc)
            if t is None or len(t) < 5:
                continue
            # Two gates, see RERUN note (c). fiajsp is the 2026-09-04 gate and
            # reproduces that draw; resolved is the engine-faithful gate,
            # eligibility computed AFTER FIAJSP, SPCTRN and the OH other slot.
            # In both cases the FULL tree list t, not a mapped subset, goes
            # forward to the keyfile builder.
            resolved_pool = resolve_stems(ik, t["SPCD"])
            n_mapped = int(t["SPCD"].isin(spmap.keys()).sum())
            n_resolved = sum(1 for (_a, _s) in resolved_pool if _s is not None)
            n_unmapped_total += len(t) - n_mapped
            is_extra = (n_resolved >= 5 and n_mapped < 5)
            if is_extra:
                n_gate_extra += 1
                et = tally(resolved_pool, t["SPCD"])
                ftc = int(c["FORTYPCD"]) if not pd.isna(c["FORTYPCD"]) else 999
                gate_extra_rows.append({
                    "state": st,
                    "fortypcd": ftc,
                    "fortyp_group": int(ftc // 10) * 10,
                    "nonstocked": int(ftc == 999),
                    "admitted": int(a.frame_gate == "resolved"),
                    "stdage": float(c["STDAGE"]),
                    "sicond_ft": float(c["SICOND"]),
                    "owner_regime": owner_regime(c.get("OWNGRPCD")),
                    "n_trees": int(len(t)),
                    "n_trees_fiajsp": int(et["fiajsp"]),
                    "n_trees_spctrn": int(et["spctrn"]),
                    "n_trees_other": int(et["other"]),
                    "n_trees_dropped": int(et["dropped"]),
                    "balive_ft2ac": (None if pd.isna(c.get("BALIVE"))
                                     else float(c.get("BALIVE"))),
                })
            gate_ok = (n_mapped >= 5) if a.frame_gate == "fiajsp" else (n_resolved >= 5)
            if not gate_ok:
                continue
            merge_tally(pool_tally, tally(resolved_pool, t["SPCD"]))
            cand.append((c, t))
        res_by_state_pool[st] = pool_tally
        log.append(f"{st}: {len(cand)} candidate stands under the "
                   f"'{a.frame_gate}' frame gate; {n_gate_extra} stands have "
                   f">=5 FVS-resolvable live stems but <5 FIAJSP mapped stems "
                   f"and are "
                   f"{'ADMITTED (engine-faithful frame; the 2026-09-04 draw is broken)' if a.frame_gate == 'resolved' else 'excluded (so the 2026-09-04 draw reproduces)'}; "
                   f"{n_unmapped_total} stems in the candidate pool fall outside "
                   f"FIAJSP and go through SPCTRN rather than being dropped")
        _ex = [r for r in gate_extra_rows if r["state"] == st]
        if _ex:
            _byft: dict[int, int] = {}
            for r in _ex:
                _byft[r["fortypcd"]] = _byft.get(r["fortypcd"], 0) + 1
            log.append(f"{st} frame-gate extra stands by FORTYPCD: "
                       f"{sorted(_byft.items(), key=lambda x: -x[1])}; "
                       f"{sum(r['nonstocked'] for r in _ex)} of {len(_ex)} are "
                       f"nonstocked (FORTYPCD 999)")
        log.append(fmt_tally(f"{st} candidate pool resolution", pool_tally))

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
                    c["FORTYPCD"]) else 504,
                "inv_year": int(c["MEASYEAR"]) if not pd.isna(
                    c.get("MEASYEAR")) else int(c["INVYR"]),
            }
            tr = [{"species": int(r.SPCD), "diameter": float(r.DIA),
                   "ht": float(r.HT), "crratio": float(r.CR),
                   "tree_count": float(r.TPA_UNADJ)}
                  for r in t.itertuples()]
            resolved = resolve_stems(ik, t["SPCD"])
            st_tally = tally(resolved, t["SPCD"])
            merge_tally(res_by_state_sample.setdefault(st, {}), st_tally)
            ftg = int((stand["forest_type"] or 999) // 10) * 10
            merge_tally(res_by_ftg.setdefault((st, ftg), {}), st_tally)
            for (alpha, stage), r in zip(resolved, t.itertuples()):
                if alpha is not None:
                    exposure_stems.append({
                        "state": st, "alpha": alpha, "tpa": float(r.TPA_UNADJ),
                        "ba": 0.005454154 * float(r.DIA) ** 2 * float(r.TPA_UNADJ)})
            n_fiajsp = st_tally["fiajsp"]
            regime = owner_regime(c.get("OWNGRPCD"))
            stand_meta.append({
                "stand_id": stand_id, "state": st, "regime": regime,
                "inv_year": stand["inv_year"], "age0": stand["age"],
                "site_index_ft": stand["site_index"],
                "fortypcd": stand["forest_type"], "n_trees": len(tr),
                "n_trees_fiajsp": n_fiajsp,
                "n_trees_spctrn": st_tally["spctrn"],
                "n_trees_other": st_tally["other"],
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
                        # and volume but no carbon. Verified empirically, not
                        # assumed. The extra cycle is projected and discarded;
                        # only offsets 0, 25 and 50 are reported.
                        "num_cycles": a.horizon // 5 + 1,
                        "fvs_modern": str(fvs_modern),
                        "fvs_bin": str(Path(a.fvs_bin).expanduser()),
                        "keyfile_module_dir": str(kdir), "scratch": a.scratch,
                    })

    # ---- resolution counts, sampled stands, per state and forest type group ----
    for st, c in res_by_state_sample.items():
        log.append(fmt_tally(f"{st} sampled stands resolution", c))
    for (st, ftg), c in sorted(res_by_ftg.items()):
        n = c["total"] or 1
        log.append(f"{st} forest type group {ftg}: {c['total']} stems, FIAJSP "
                   f"{c['fiajsp']}, SPCTRN {c['spctrn']} ({100*c['spctrn']/n:.2f}%), "
                   f"OH {c['other']} ({100*c['other']/n:.2f}%), dropped {c['dropped']}")
    log.extend(keyword_exposure_by_state(exposure_stems, kwinfo, sp_index))

    # ---- stand set identity against the prior run ----
    if a.prior_inventory:
        prev = pd.read_csv(Path(a.prior_inventory).expanduser())
        cur = pd.DataFrame(stand_meta)
        keys = ["stand_id", "state", "regime", "inv_year", "age0",
                "site_index_ft", "fortypcd"]
        same = (len(prev) == len(cur)
                and prev[keys].reset_index(drop=True).equals(
                    cur[keys].reset_index(drop=True)))
        dn = int((cur["n_trees"].values - prev["n_trees"].values).sum()) if len(prev) == len(cur) else None
        log.append(f"stand set identity against {a.prior_inventory}: "
                   f"{'IDENTICAL' if same else 'DIFFERENT'} on {keys}; "
                   f"sampled tree records {int(cur['n_trees'].sum())} against "
                   f"{int(prev['n_trees'].sum())} prior (+{dn} stems now reaching "
                   f"the keyfile through SPCTRN or OH)")
        if not same and a.frame_gate == "fiajsp":
            raise RuntimeError("sampled stand set differs from the prior run; the "
                               "SPCTRN effect would be confounded, refusing to run")
        if not same and a.frame_gate == "resolved":
            log.append("stand set difference is EXPECTED under --frame-gate "
                       "resolved: the engine-faithful gate enlarges the candidate "
                       "pool, which changes the seeded stratified draw. The prior "
                       "inventory is reported here for provenance only and the "
                       "identity check is advisory, not enforcing.")
            for col in ("age0", "site_index_ft", "n_trees"):
                log.append(f"stand set attribute {col}: prior mean "
                           f"{prev[col].mean():.3f}, current mean "
                           f"{cur[col].mean():.3f}")
            _pn = prev.groupby("state")["stand_id"].count().to_dict()
            _cn = cur.groupby("state")["stand_id"].count().to_dict()
            log.append(f"stands per state prior {_pn}, current {_cn}")

    log.append(f"total FVS runs queued: {len(jobs)} "
               f"({len(stand_meta)} stands x {len(scenarios)} scenarios x 2 arms)")
    print("\n".join(log), flush=True)

    traj = []
    failed = []
    done = 0
    worker_counts: dict[str, dict] = {}
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
            # one record per stand (every scenario and arm sees the same
            # tree list, so any of the ten runs carries the same counts)
            worker_counts.setdefault(r["stand_id"], r["res_counts"])
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

    tdf = pd.DataFrame(traj)
    # Drop the extra carbon-report cycle so no row past the stated 50-year
    # horizon appears in any deliverable.
    tdf = tdf[tdf["year_offset"] <= a.horizon]
    d = a.out_date

    # Module counters from the workers against the driver's own tally.
    wc = {k: sum(v[k] for v in worker_counts.values())
          for k in ("total_stems", "fiajsp_stems", "spctrn_stems",
                    "other_stems", "dropped_stems")}
    mine = {}
    for c in res_by_state_sample.values():
        merge_tally(mine, c)
    agree = all(wc[f"{k}_stems"] == mine[k]
                for k in ("fiajsp", "spctrn", "other", "dropped")) \
        and wc["total_stems"] == mine["total"]
    log.append(f"module get_species_resolution_counts summed over "
               f"{len(worker_counts)} stands: {wc}; driver tally "
               f"{ {k: mine[k] for k in ('total','fiajsp','spctrn','other','dropped')} }; "
               f"{'AGREE' if agree else 'DISAGREE'}")
    tdf.to_csv(outdir / f"fvs-ne-stand-trajectories_DATA_{d}.csv", index=False)
    pd.DataFrame(stand_meta).to_csv(
        outdir / f"fvs-ne-stand-inventory_DATA_{d}.csv", index=False)
    if failed:
        pd.DataFrame(failed).to_csv(
            outdir / f"fvs-ne-failed-runs_DATA_{d}.csv", index=False)

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
    summ["pathway"] = "FVS-NE"
    summ["horizon_years"] = a.horizon
    summ.to_csv(outdir / f"fvs-ne-state-summary_DATA_{d}.csv", index=False)

    # Machine readable resolution counts and keyword inventory alongside the
    # log, keyed by state and forest type group only (no stand identifiers).
    def _plain(c):
        return {k: (dict(v) if isinstance(v, dict) else v) for k, v in c.items()}
    (outdir / f"fvs-ne-species-resolution_DATA_{d}.json").write_text(json.dumps({
        "candidate_pool_by_state": {s: _plain(c) for s, c in res_by_state_pool.items()},
        "sampled_by_state": {s: _plain(c) for s, c in res_by_state_sample.items()},
        "sampled_by_state_fortyp_group": {f"{s}_{g}": _plain(c)
                                          for (s, g), c in res_by_ftg.items()},
        "module_counts_from_workers": wc,
        "keyword_inventory": {k: {kk: vv for kk, vv in v.items() if kk != "per_species"}
                              for k, v in kwinfo.items()},
    }, indent=1, default=str))

    # Frame-gate diagnostic. One row per stand that the engine-faithful gate
    # admits and the FIAJSP gate does not. No PLT_CN, no coordinate, no stand
    # id: this is a condition-level description of the frame difference only.
    if gate_extra_rows:
        pd.DataFrame(gate_extra_rows).to_csv(
            outdir / f"fvs-ne-frame-gate-extra_DATA_{d}.csv", index=False)
    log.append(f"frame gate '{a.frame_gate}': {len(gate_extra_rows)} stands across "
               f"all states have >=5 resolvable stems but <5 FIAJSP mapped stems; "
               f"{sum(r['nonstocked'] for r in gate_extra_rows)} of them are "
               f"nonstocked (FORTYPCD 999)")

    (outdir / f"fvs-ne-run-log_DATA_{d}.txt").write_text(
        "\n".join(log) + f"\n\nfailed runs: {len(failed)} of {len(jobs)}\n")
    print("\n".join(log))
    print(f"failed runs: {len(failed)} of {len(jobs)}")
    print(summ.to_string(index=False))


if __name__ == "__main__":
    main()
