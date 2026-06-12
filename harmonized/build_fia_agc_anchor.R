#!/usr/bin/env Rscript
# build_fia_agc_anchor.R
#
# Interim FIA year-0 live aboveground carbon (AGC) anchor per state for the
# harmonized cross-model assessment (harmonized_scenarios.yml). One common
# year-0 stock per state, used to rescale every model's dynamics:
#   model_anchored(t) = model(t) * (FIA_y0 / model_y0)
#
# METHOD (interim, transparent): mean live AGC per forested acre across FIA
# plots, times state forest area. This is NOT the design-based stratified
# estimator. The publication anchor multiplies tree CARBON_AG by TPA_UNADJ by
# the stratum EXPNS (POP_STRATUM.EXPNS via POP_PLOT_STRATUM_ASSGN). That
# assignment table is absent from the FIA cache on Cardinal; download
# POP_PLOT_STRATUM_ASSGN (or use rFIA::carbon) for the refined version.
#
# Inputs : FIA state CSV bundles ({ST}_TREE.csv, {ST}_COND.csv) and the
#          consolidated HCS table (state forest_ha, harmonized forest-area basis).
# Output : fia_agc_anchor_interim_by_state.csv
#          columns: state, n_forested_plots, agc_MgC_ha, forest_ha, agc_TgC_total
#
# Run on Cardinal:  module load gcc/12.3.0; module load R/4.4.0; Rscript build_fia_agc_anchor.R

suppressPackageStartupMessages({
  library(data.table)   # fread(select=) keeps memory low on the wide TREE tables
})

fia_dir <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
hcs_csv <- "/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv"
out_csv <- file.path(fia_dir, "fia_agc_anchor_interim_by_state.csv")

# lbs C / acre  ->  Mg C / ha
LBS_AC_TO_MG_HA <- 0.45359237 / 1000 * 2.47105

hcs <- fread(hcs_csv, select = c("state", "forest_ha"))

tree_files <- list.files(fia_dir, pattern = "^[A-Z]{2}_TREE\\.csv$", full.names = TRUE)
states <- sub("_TREE\\.csv$", "", basename(tree_files))

rows <- lapply(states, function(st) {
  tf <- file.path(fia_dir, paste0(st, "_TREE.csv"))
  cf <- file.path(fia_dir, paste0(st, "_COND.csv"))
  if (!file.exists(cf)) return(NULL)

  # forested, accessible conditions -> set of plot control numbers
  cond <- fread(cf, select = c("PLT_CN", "COND_STATUS_CD"))
  forested <- unique(cond[COND_STATUS_CD == 1L, PLT_CN])

  # live trees only; per-plot live AGC in lbs/acre
  tree <- fread(tf, select = c("PLT_CN", "STATUSCD", "TPA_UNADJ", "CARBON_AG"))
  tree <- tree[STATUSCD == 1L & PLT_CN %in% forested &
                 !is.na(CARBON_AG) & !is.na(TPA_UNADJ)]
  if (!nrow(tree)) return(NULL)

  per_plot <- tree[, .(agc_lbs_ac = sum(CARBON_AG * TPA_UNADJ)), by = PLT_CN]
  agc_mg_ha <- mean(per_plot$agc_lbs_ac) * LBS_AC_TO_MG_HA
  fha <- hcs[state == st, forest_ha]
  fha <- if (length(fha)) fha[1] else NA_real_

  data.table(state = st,
             n_forested_plots = nrow(per_plot),
             agc_MgC_ha = round(agc_mg_ha, 2),
             forest_ha = fha,
             agc_TgC_total = round(agc_mg_ha * fha / 1e6, 2))
})

anchor <- rbindlist(rows)
setorder(anchor, agc_MgC_ha)
fwrite(anchor, out_csv)

cat(sprintf("Wrote %s (%d states)\n", out_csv, nrow(anchor)))
cat(sprintf("CONUS live AGC: %.0f Tg C (%.2f Pg C)\n",
            sum(anchor$agc_TgC_total, na.rm = TRUE),
            sum(anchor$agc_TgC_total, na.rm = TRUE) / 1000))
