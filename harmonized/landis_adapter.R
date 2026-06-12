#!/usr/bin/env Rscript
# landis_adapter.R
#
# Adapts per-plot LANDIS-II output to the harmonized common schema so it can
# flow through treemap_paint.R / harmonized_aggregate.R.
#
#   LANDIS per plot: runs/plot_*/biomass_trajectory.csv (plot_id, year, TotalBiomass_gm2)
#   plot_id -> plt_cn via perseus/plot_ics_full/_summary.csv (plot_id, plt_cn)
#   agc_MgC_ha = TotalBiomass_gm2 * 0.01 (g/m2 -> Mg/ha) * carbon_fraction
#   year(calendar) = 2025 + elapsed_year, kept through 2100 (harmonized horizon)
#
# Output (common schema): model, scenario, PLT_CN, year, agc_MgC_ha
#
# Usage: Rscript landis_adapter.R --state WA --chain wa_t2v2_calibrated \
#          --scenario reserve --cfrac 0.5 --out landis_WA_reserve.csv
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
ga <- function(f,d=NA){ i<-match(f,args); if(is.na(i)||i==length(args)) d else args[i+1] }
L      <- "/fs/scratch/PUOM0008/crsfaaron/landis2"
st     <- ga("--state","WA")
chain  <- ga("--chain", NA)
scen   <- ga("--scenario","reserve")
cfrac  <- as.numeric(ga("--cfrac","0.5"))
base   <- file.path(L,"states",st,"perseus","statewide")
if (is.na(chain)) chain <- list.files(base, pattern="_calibrated$")[1]
W      <- file.path(base, chain)
out    <- ga("--out", sprintf("landis_%s_%s.csv", st, scen))

# plot_id -> plt_cn  (IC summary lives under perseus/, not the chain dir)
summ_path <- file.path(L,"states",st,"perseus","plot_ics_full","_summary.csv")
if (!file.exists(summ_path)) summ_path <- file.path(W,"plot_ics_full","_summary.csv")
summ <- fread(summ_path)
if (!"plot_id" %in% names(summ)) setnames(summ, grep("plot_id|plot", names(summ), value=TRUE)[1], "plot_id")
map <- summ[, .(plot_id, PLT_CN = as.character(plt_cn))]

# read all per-plot trajectories
tfs <- list.files(file.path(W,"runs"), pattern="biomass_trajectory.csv",
                  recursive=TRUE, full.names=TRUE)
traj <- rbindlist(lapply(tfs, fread), fill=TRUE)
setnames(traj, c("plot_id","year","TotalBiomass_gm2")[1:ncol(traj)], skip_absent=TRUE)

d <- merge(traj, map, by="plot_id")
d[, agc_MgC_ha := TotalBiomass_gm2 * 0.01 * cfrac]
d[, year := 2025 + year]
d <- d[year <= 2100]
d[, `:=`(model="LANDIS", scenario=scen)]
res <- d[, .(model, scenario, PLT_CN, year, agc_MgC_ha)][order(PLT_CN, year)]
fwrite(res, out)
cat(sprintf("[LANDIS %s/%s] %d plots, %d rows, years %s -> %s\n",
            st, scen, uniqueN(res$PLT_CN), nrow(res), min(res$year), max(res$year)))
cat(sprintf("  matched plot->CN: %d of %d trajectory plots\n", uniqueN(d$plot_id), uniqueN(traj$plot_id)))
print(res[year %in% c(2025,2100)][, .(meanAGC = round(mean(agc_MgC_ha),1)), by=year])
