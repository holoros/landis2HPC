#!/usr/bin/env Rscript
# treemap_paint.R
#
# Shared spatial layer for the harmonized assessment. Every model is run per FIA
# plot (output keyed by PLT_CN). TreeMap imputes an FIA plot to every 30 m pixel,
# so each plot CN represents a known landscape area. This script "paints" any
# per-plot per-ha value onto the landscape by joining on PLT_CN, then aggregates
# to any domain (state, county, ecoregion, hex). It is the single mechanism by
# which plot-level model output becomes a spatially explicit, area-weighted map.
#
#   domain_total   = sum over plots in D of ( value_per_ha(PLT_CN) * area_ha(PLT_CN) )
#   domain_per_ha  = domain_total / sum(area_ha in D)
#
# Painting weight: plt_area_treemap.csv (PLT_CN, area_ha) = TreeMap ha per plot.
# Pixel-level maps use the TM_ID -> PLT_CN donor raster (me_treemap_donors.csv pattern).
#
# Usage:
#   Rscript treemap_paint.R --plot-values model_out.csv --domain state --out painted.csv
#     model_out.csv: columns PLT_CN, value_per_ha (e.g. Mg C/ha)
#   Rscript treemap_paint.R --validate-state ME   # paints FIA live AGC, checks vs design
#
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
ga <- function(f, d = NA) { i <- match(f, args); if (is.na(i) || i == length(args)) d else args[i+1] }
fia      <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
area_csv <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress/plt_area_treemap.csv"

area <- fread(area_csv, select = c("PLT_CN","area_ha"))
area[, PLT_CN := as.character(PLT_CN)]

# PLT_CN -> domain key (state/county) from a state PLOT file or all PLOT files
plot_domain <- function(states, domain) {
  pf <- if (length(states) == 1) file.path(fia, paste0(states, "_PLOT.csv")) else NA
  pl <- fread(pf, select = c("CN","STATECD","COUNTYCD"))
  setnames(pl, "CN", "PLT_CN"); pl[, PLT_CN := as.character(PLT_CN)]
  pl[, dom := if (domain == "county") sprintf("%02d%03d", STATECD, COUNTYCD) else sprintf("%02d", STATECD)]
  unique(pl[, .(PLT_CN, dom)])
}

paint <- function(vals, dom_map) {
  d <- merge(vals, area, by = "PLT_CN")          # plot value x TreeMap area
  d <- merge(d, dom_map, by = "PLT_CN")
  d[, mgC := value_per_ha * area_ha]
  d[, .(n_plots = .N, area_ha = sum(area_ha),
        painted_TgC = round(sum(mgC)/1e6, 2),
        per_ha_MgC  = round(sum(mgC)/sum(area_ha), 2)), by = dom][order(dom)]
}

## ---- validation mode: paint FIA live AGC for one state, compare to design ----
if (!is.na(ga("--validate-state"))) {
  st <- ga("--validate-state")
  LB2MG <- 0.45359237/1000
  forested <- unique(fread(file.path(fia, paste0(st,"_COND.csv")),
                           select=c("PLT_CN","COND_STATUS_CD"))[COND_STATUS_CD==1, PLT_CN])
  tr <- fread(file.path(fia, paste0(st,"_TREE.csv")),
              select=c("PLT_CN","STATUSCD","TPA_UNADJ","CARBON_AG"))
  tr <- tr[STATUSCD==1 & PLT_CN %in% forested & !is.na(CARBON_AG) & !is.na(TPA_UNADJ)]
  vals <- tr[, .(value_per_ha = sum(CARBON_AG*TPA_UNADJ)*LB2MG*2.47105), by=PLT_CN]  # Mg C/ha
  vals[, PLT_CN := as.character(PLT_CN)]
  dm <- plot_domain(st, "state")
  res <- paint(vals, dm)
  cat(sprintf("TreeMap-painted FIA live AGC, %s:\n", st)); print(res)
  cat(sprintf("  (compare to design EXPNS total in fia_design_validate.csv)\n"))
  quit(save="no")
}

## ---- production mode: paint an arbitrary model output ----
vals <- fread(ga("--plot-values")); setnames(vals, 1:2, c("PLT_CN","value_per_ha"))
vals[, PLT_CN := as.character(PLT_CN)]
domain <- ga("--domain","state")
states <- unique(substr(vals$PLT_CN,1,0))  # placeholder; pass states via PLOT files
dm <- plot_domain(ga("--states","ME"), domain)
res <- paint(vals, dm)
fwrite(res, ga("--out","painted.csv")); print(res)
