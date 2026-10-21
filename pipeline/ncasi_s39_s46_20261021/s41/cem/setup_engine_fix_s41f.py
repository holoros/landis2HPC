#!/usr/bin/env python3
"""s41 step F setup (16 Oct 2026). Builds two engine copies from the s41 engine
copy (which already carries the output only donor pair patch) and writes
unified diffs against the production files.
  engine_fix1: F1 subject id fix in R/02_cem_matching.R (global .cem_sid
               assigned once before the three CEM passes; subject_row = .cem_sid,
               so stacked passes cannot collide and every select / bias step that
               groups on subject_row groups on the global id).
  engine_fix2: F1 + F2 + M1 option.
     F2 (defect): R/06_projection_engine.R project_multi_cycle carries the site
        constant matching keys (us_l3code, us_l3name, asym_agb) into the next
        cycle's subjects; they were dropped by the transmute, so from cycle 2
        the ecoregion key was 0 and passes 1 and 2 never matched.
     M1 (model change, off unless CEM_NO_AGE_SAT=1): sat_for_age returns 1.
Production tree is not modified."""
import os, shutil, subprocess, sys
W = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
SRC_PROD = os.path.expanduser("~/fia_cem_projections")
BASE = os.path.join(W, "engine")

def rep(path, old, new, count=1):
    s = open(path).read()
    n = s.count(old)
    if n != count:
        sys.exit(f"PATCH FAIL {path}: expected {count} got {n} for {old[:60]!r}")
    open(path, "w").write(s.replace(old, new))

def clone(name):
    dst = os.path.join(W, name)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(os.path.join(dst, "output"))
    shutil.copy2(os.path.join(BASE, "run_projection.R"), dst)
    shutil.copytree(os.path.join(BASE, "R"), os.path.join(dst, "R"))
    os.symlink(os.path.join(SRC_PROD, "config"), os.path.join(dst, "config"))
    os.symlink(os.path.join(SRC_PROD, "data"), os.path.join(dst, "data"))
    open(os.path.join(dst, ".here"), "w").close()
    return dst

def f1(dst):
    p = os.path.join(dst, "R", "02_cem_matching.R")
    rep(p, "  all_match_pairs <- tibble()\n",
        "  # F1 fix (s41, 16 Oct 2026): one global subject id, assigned once before the\n"
        "  # three passes. subject_row was row_number() inside each pass, so ids from\n"
        "  # passes 2 and 3 collided with pass 1 and the one-row-per-subject_row\n"
        "  # selection dropped subjects at random.\n"
        "  subjects <- subjects |> mutate(.cem_sid = row_number())\n"
        "  all_match_pairs <- tibble()\n")
    rep(p, "    mutate(subject_row = row_number()) |>\n",
        "    mutate(subject_row = if (\".cem_sid\" %in% names(subj_c)) .cem_sid else row_number()) |>  # F1\n",
        count=3)

def f2(dst):
    p = os.path.join(dst, "R", "06_projection_engine.R")
    rep(p, "        LAT, LON, ELEV, PLT_CN\n      )\n  }\n",
        "        LAT, LON, ELEV, PLT_CN\n      )\n"
        "    # F2 fix (s41, 16 Oct 2026): carry site constant matching keys into the\n"
        "    # next cycle. The transmute above dropped them, so from cycle 2 the\n"
        "    # ecoregion key was 0 and CEM passes 1 and 2 never matched.\n"
        "    .keys <- intersect(c(\"us_l3code\", \"us_l3name\", \"asym_agb\"), names(subjects))\n"
        "    if (length(.keys) > 0) {\n"
        "      current_subjects <- current_subjects |>\n"
        "        dplyr::left_join(subjects |>\n"
        "          dplyr::select(STATECD, COUNTYCD, PLOT, CONDID, dplyr::all_of(.keys)) |>\n"
        "          dplyr::distinct(STATECD, COUNTYCD, PLOT, CONDID, .keep_all = TRUE),\n"
        "          by = c(\"STATECD\", \"COUNTYCD\", \"PLOT\", \"CONDID\"))\n"
        "    }\n  }\n")
    rep(p, "  sat_for_age <- function(age, term = terminal_age, gstart = growth_start_age) {\n",
        "  sat_for_age <- function(age, term = terminal_age, gstart = growth_start_age) {\n"
        "    # M1 model change option (s41, 16 Oct 2026): with CEM_NO_AGE_SAT=1 the\n"
        "    # age saturation ramp is disabled; donors are already matched on the\n"
        "    # current age class each cycle (Van Deusen and Roesch 2013).\n"
        "    if (identical(Sys.getenv(\"CEM_NO_AGE_SAT\"), \"1\")) return(rep(1, length(age)))\n")

def udiff(prod_rel, new_path, out):
    r = subprocess.run(["diff", "-u", "--label", "a/" + prod_rel, "--label", "b/" + prod_rel,
                        os.path.join(SRC_PROD, prod_rel), new_path], capture_output=True, text=True)
    open(out, "a").write(r.stdout)

d1 = clone("engine_fix1"); f1(d1)
d2 = clone("engine_fix2"); f1(d2); f2(d2)
for f in ["cem_subject_id_fix_20261016.patch", "cem_cycle_keys_and_age_option_20261016.patch"]:
    fp = os.path.join(W, f)
    if os.path.exists(fp): os.remove(fp)
udiff("R/02_cem_matching.R", os.path.join(d1, "R", "02_cem_matching.R"), os.path.join(W, "cem_subject_id_fix_20261016.patch"))
# second patch: F2 and M1 only (diffed against the s41 copy so the output only
# d_CONDID line is not included; hunks are far from it, so it applies to production)
r = subprocess.run(["diff", "-u", "--label", "a/R/06_projection_engine.R", "--label", "b/R/06_projection_engine.R",
                    os.path.join(BASE, "R", "06_projection_engine.R"), os.path.join(d2, "R", "06_projection_engine.R")],
                   capture_output=True, text=True)
open(os.path.join(W, "cem_cycle_keys_and_age_option_20261016.patch"), "w").write(r.stdout)
# check both patches apply to the production tree (dry run)
for pf in ["cem_subject_id_fix_20261016.patch", "cem_cycle_keys_and_age_option_20261016.patch"]:
    r = subprocess.run(["patch", "--dry-run", "-p1", "-d", SRC_PROD, "-i", os.path.join(W, pf)], capture_output=True, text=True)
    print(pf, "dry run:", r.returncode, r.stdout.strip().replace(chr(10), " | "))
for d in (d1, d2):
    subprocess.run(["md5sum", os.path.join(d, "R", "02_cem_matching.R"), os.path.join(d, "R", "06_projection_engine.R"), os.path.join(d, "run_projection.R")])
print("SETUP_F_DONE")
