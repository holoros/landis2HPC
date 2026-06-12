#!/usr/bin/env Rscript
# fia_domain_estimator.R
#
# Multi-resolution FIA live-tree carbon/biomass estimator for the harmonized
# assessment. One framework, three spatial domains: state, county, EPA L3
# ecoregion. Designed to MIRROR official FIA estimates.
#
# TWO ESTIMATION MODES
#   (1) design  : the FIA design-based estimator that reproduces EVALIDator.
#                 total_D = sum over plots p in D of
#                   EXPNS(p) * sum_trees( ATTR * TPA_UNADJ * ADJ_FACTOR )
#                 Requires POP_PLOT_STRATUM_ASSGN (PLT_CN -> STRATUM_CN) joined
#                 to POP_STRATUM (EXPNS, ADJ_FACTOR_SUBP/MICR/MACR). This table
#                 is NOT in the Cardinal FIA cache yet; download it from the FIA
#                 Datamart to switch this mode on. It is the publication path.
#   (2) ratio   : interim, transparent. Mean attribute per forested acre across
#                 plots in D, times domain forest area. No EXPNS needed; runs on
#                 the data in hand. Used until the assignment table lands.
#
# DOMAINS
#   state     : STATECD                          (PLOT)
#   county    : STATECD x COUNTYCD               (PLOT)  -- FIA's focal unit
#   ecoregion : EPA Level III                    (plot -> L3 via lat/lon join)
#               needs a plot->ECO_L3 crosswalk (build once with sf against
#               Disturbance/us_eco_l3.shp using PLOT.LAT/LON), passed via
#               --eco-crosswalk. Until then ecoregion is skipped with a note.
#
# ATTRIBUTE: any per-tree TREE column (default CARBON_AG, oven-dry lbs of
#   aboveground carbon). Live trees = STATUSCD==1, forested conditions only.
#
# Usage:
#   Rscript fia_domain_estimator.R --domain county --states ME,WA
#   Rscript fia_domain_estimator.R --domain state  --mode design   # when ASSGN present
#
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))

## ---- args ----
args <- commandArgs(trailingOnly = TRUE)
getarg <- function(flag, default = NA) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
domain   <- getarg("--domain", "state")          # state | county | ecoregion
mode     <- getarg("--mode", "ratio")            # ratio | design
attr_col <- getarg("--attr", "CARBON_AG")
states   <- getarg("--states", "ALL")
eco_xwalk<- getarg("--eco-crosswalk", NA)        # csv: PLT_CN, ECO_L3
fia_dir  <- getarg("--fia-dir", "/fs/scratch/PUOM0008/crsfaaron/FIA")
hcs_csv  <- getarg("--hcs", "/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv")
out_csv  <- getarg("--out", sprintf("fia_agc_%s_%s.csv", domain, mode))

LBS_AC_TO_MG_HA <- 0.45359237 / 1000 * 2.47105
assgn_path <- file.path(fia_dir, "ENTIRE_POP_PLOT_STRATUM_ASSGN.csv")
if (mode == "design" && !file.exists(assgn_path)) {
  stop("mode=design needs ", assgn_path, " (POP_PLOT_STRATUM_ASSGN). Absent from cache; download from FIA Datamart.")
}

tree_files <- list.files(fia_dir, pattern = "^[A-Z]{2}_TREE\\.csv$", full.names = TRUE)
all_states <- sub("_TREE\\.csv$", "", basename(tree_files))
keep <- if (states == "ALL") all_states else strsplit(states, ",")[[1]]

eco <- if (!is.na(eco_xwalk) && file.exists(eco_xwalk)) fread(eco_xwalk) else NULL
if (domain == "ecoregion" && is.null(eco)) {
  stop("domain=ecoregion needs --eco-crosswalk PLT_CN,ECO_L3 (build with sf vs us_eco_l3.shp).")
}
hcs <- if (file.exists(hcs_csv)) fread(hcs_csv, select = c("state","forest_ha")) else NULL

## ---- per-state plot-level live attribute (lbs/acre on forested conditions) ----
plot_level <- function(st) {
  tf <- file.path(fia_dir, paste0(st, "_TREE.csv"))
  cf <- file.path(fia_dir, paste0(st, "_COND.csv"))
  pf <- file.path(fia_dir, paste0(st, "_PLOT.csv"))
  if (!all(file.exists(tf, cf, pf))) return(NULL)

  forested <- unique(fread(cf, select = c("PLT_CN","COND_STATUS_CD"))[COND_STATUS_CD == 1L, PLT_CN])
  tr <- fread(tf, select = c("PLT_CN","STATUSCD","TPA_UNADJ", attr_col))
  setnames(tr, attr_col, "ATTR")
  tr <- tr[STATUSCD == 1L & PLT_CN %in% forested & !is.na(ATTR) & !is.na(TPA_UNADJ)]
  if (!nrow(tr)) return(NULL)
  pp <- tr[, .(attr_lbs_ac = sum(ATTR * TPA_UNADJ)), by = PLT_CN]

  pl <- fread(pf, select = c("CN","STATECD","COUNTYCD"))
  setnames(pl, "CN", "PLT_CN")
  pp <- merge(pp, pl, by = "PLT_CN", all.x = TRUE)
  if (!is.null(eco)) pp <- merge(pp, eco, by = "PLT_CN", all.x = TRUE)
  pp
}

dat <- rbindlist(lapply(keep, plot_level), fill = TRUE)
if (!nrow(dat)) stop("no plot data assembled")

## ---- domain key ----
dat[, dom := switch(domain,
  state     = sprintf("%02d", STATECD),
  county    = sprintf("%02d%03d", STATECD, COUNTYCD),
  ecoregion = as.character(ECO_L3))]

## ---- aggregate (ratio mode: per-acre mean -> Mg C/ha) ----
res <- dat[, .(n_plots = .N,
               agc_MgC_ha = round(mean(attr_lbs_ac) * LBS_AC_TO_MG_HA, 2)),
           by = dom][order(dom)]

# state totals via HCS forest area where available
if (domain == "state" && !is.null(hcs)) {
  res <- merge(res, hcs[, .(dom = state, forest_ha)], by = "dom", all.x = TRUE)
  res[, agc_TgC_total := round(agc_MgC_ha * forest_ha / 1e6, 2)]
}

fwrite(res, out_csv)
cat(sprintf("[%s/%s] wrote %s : %d domains, %d plots\n",
            domain, mode, out_csv, nrow(res), sum(res$n_plots)))
print(utils::head(res, 12))
