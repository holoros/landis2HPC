# Track G: derive variant/copies from Track A scripts (originals left untouched in landis_memn)
S="/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn"
G="/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit"
def sub1(t, a, b):
    assert t.count(a) == 1, (a, t.count(a)); return t.replace(a, b)
# 1 builder variant: age backstop median over forested CONDID 1 rows only
t = open("build_ic_v3_drybio_s43.R").read()
t = sub1(t, 'median_age <- as.integer(median(cond1$STDAGE, na.rm = TRUE))',
 'median_age_all <- as.integer(median(cond1$STDAGE, na.rm = TRUE))\n'
 '# Track G variant (fsta): backstop median over forested condition 1 rows only (COND_STATUS_CD == 1), same pmax(.,1) transform\n'
 'condF <- cond[CONDID == 1 & COND_STATUS_CD == 1, .(STDAGE = as.integer(pmax(STDAGE, 1L, na.rm = TRUE)))]\n'
 'median_age <- as.integer(median(condF$STDAGE, na.rm = TRUE))\n'
 'log("   [fsta] forested CONDID 1 rows:", nrow(condF), " forested median:", median_age, "yr; all-rows median (original rule):", median_age_all, "yr")')
open("build_ic_v3_drybio_s43_fsta.R", "w").write(t)
# 2 builder slurm
t = open("build_ic_s43.slurm").read()
t = t.replace(S, G).replace("build_ic_v3_drybio_s43.R", "build_ic_v3_drybio_s43_fsta.R").replace("s43A_ic", "s43G_ic")
open("build_ic_fsta.slurm", "w").write(t)
# 3 preanchor
t = open("preanchor_gates_anchor_s43.R").read(); t = sub1(t, 'T <- "%s"' % S, 'T <- "%s"' % G)
open("preanchor_gates_anchor_s43G.R", "w").write(t)
open("pa_G.slurm", "w").write("#!/bin/bash\n#SBATCH --account=PUOM0008 --time=02:00:00 --nodes=1 --cpus-per-task=4 --mem=200G --job-name=s43G_pa\n"
 "#SBATCH --output=%s/logs/preanchor_%%x_%%j.out\nmodule load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1\n"
 "echo md5 $(md5sum < %s/scripts/preanchor_gates_anchor_s43G.R | cut -c1-8)\nRscript %s/scripts/preanchor_gates_anchor_s43G.R $ST $ETAG\n" % (G, G, G))
# 4 smoke script: T -> G; BUILD=orig uses Track A build (read only) with base270_orig, BUILD=fsta uses Track G build
t = open("smoke_run_s43.sh").read()
t = sub1(t, "T=%s\n" % S, "T=%s; SA=%s\n" % (G, S))
t = sub1(t, "BD=$T/build/$ST/initial_communities; B270=$T/runs/$ST/base270;",
 'if [ "$BUILD" = orig ]; then BD=$SA/build/$ST/initial_communities; else BD=$T/build/$ST/initial_communities; fi; B270=$T/runs/$ST/base270_$BUILD;')
t = sub1(t, "#SBATCH --output=%s/logs/" % S, "#SBATCH --output=%s/logs/" % G)
t = sub1(t, "# Env: ST RN SRCT (source SppEcoregion table) A B PE ETAG", "# Env: ST RN SRCT (source SppEcoregion table) A B PE ETAG BUILD(orig|fsta)  [Track G copy]")
t = sub1(t, 'echo "$ST $RN table=$SRCT', 'echo "$ST $RN build=$BUILD bd=$BD table=$SRCT')
open("smoke_run_s43G.sh", "w").write(t)
# 5 scorer: T -> G, run root and name filter as args, skip base270_*
t = open("score_memn_s43b.R").read()
t = sub1(t, 'TAG <- commandArgs(TRUE)[1]', 'ARGS <- commandArgs(TRUE); TAG <- ARGS[1]')
t = sub1(t, 'T <- "%s"; O <- file.path(T, "out")' % S,
 'T <- "%s"; O <- file.path(T, "out")\nRR <- if (length(ARGS) >= 2) ARGS[2] else file.path(T, "runs"); PAT <- if (length(ARGS) >= 3) ARGS[3] else "."  # Track G: run root, run-name regex' % G)
t = sub1(t, 'for (R in list.dirs(file.path(T, "runs", st), recursive = FALSE)) { if (basename(R) == "base270") next',
 'for (R in list.dirs(file.path(RR, st), recursive = FALSE)) { if (grepl("^base270", basename(R)) || !grepl(PAT, basename(R))) next')
t = sub1(t, 'readLines(file.path(T, "runs", st, rn, "RUN_SPEC.txt"))', 'readLines(file.path(RR, st, rn, "RUN_SPEC.txt"))')
t = sub1(t, 'file.path(T, "runs", res[run == rn, state], rn, "SppEcoregionData_fia.csv")', 'file.path(RR, res[run == rn, state], rn, "SppEcoregionData_fia.csv")')
open("score_memn_s43G.R", "w").write(t)
open("score_G.slurm", "w").write("#!/bin/bash\n#SBATCH --account=PUOM0008 --time=01:30:00 --nodes=1 --cpus-per-task=4 --mem=120G --job-name=s43G_score\n"
 "#SBATCH --output=%s/logs/score_%%j.out\nmodule load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1\n"
 "echo md5 $(md5sum < %s/scripts/score_memn_s43G.R | cut -c1-8)\nRscript %s/scripts/score_memn_s43G.R $TAG $RR $PAT\n" % (G, G, G))
print("PATCH_OK")
