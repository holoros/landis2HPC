# fia_nfi_removal_benchmark.R  <STATE>
# Build the FIA NFI harvest removal benchmark for one state, to calibrate the
# harmonized common harvest (HCS) layer. Uses rFIA::growMort on the locally staged
# FIADB (downloads only the few GRM tables that are missing, read local first).
# Output row: state, year, remv_perc (annual removal as % of standing aboveground
# biomass), remv_bio_ag (absolute, short tons/yr), prev_bio_ag. REMV_PERC is the
# empirical annual removal rate, directly comparable to our h*f effective rate.
suppressMessages({library(rFIA); library(data.table)})
options(timeout = max(3600L, getOption("timeout")))

args <- commandArgs(trailingOnly = TRUE)
st   <- args[1]
ddir <- file.path(Sys.getenv("HOME"), "fia_data")
odir <- "/fs/scratch/PUOM0008/crsfaaron/FIA/nfi_benchmark"
dir.create(odir, showWarnings = FALSE, recursive = TRUE)

need <- c("PLOT","COND","TREE","TREE_GRM_COMPONENT","TREE_GRM_MIDPT","TREE_GRM_BEGIN",
          "SUBP_COND_CHNG_MTRX","PLOTGEOM","POP_ESTN_UNIT","POP_EVAL","POP_EVAL_TYP",
          "POP_EVAL_GRP","POP_PLOT_STRATUM_ASSGN","POP_STRATUM")

# Download only the tables that are not already staged locally for this state.
missing <- need[!file.exists(file.path(ddir, paste0(st, "_", need, ".csv")))]
if (length(missing) > 0) {
  cat(sprintf("[%s] downloading missing tables: %s\n", st, paste(missing, collapse=", ")))
  getFIA(states = st, dir = ddir, tables = missing, load = FALSE)
}

db <- readFIA(dir = ddir, states = st, tables = need)

# Removal as a rate on standing aboveground biomass. REMV_PERC is annual removals
# as a percent of previous standing, the empirical analogue of our h*f rate.
gm <- growMort(db, stateVar = "BIO_AG", totals = TRUE, variance = FALSE)
gm <- as.data.table(gm)

keep <- intersect(c("YEAR","REMV_PERC","REMV_TOTAL","PREV_TOTAL","CURR_TOTAL"), names(gm))
out  <- gm[, ..keep]
out[, state := st]
setcolorder(out, c("state", keep))

# Most recent year is the contemporary benchmark.
fwrite(out, file.path(odir, paste0("nfi_removal_", st, ".csv")))
cat(sprintf("[%s] done. latest REMV_PERC = %.3f %%/yr\n",
            st, tail(out$REMV_PERC, 1)))
