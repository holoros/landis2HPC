#!/usr/bin/env Rscript
## extract_me_spatial_reserve.R - turn the Maine spatial LANDIS-II landscape run into a
## per-year carbon trajectory and compare it to the PER-PLOT LANDIS reserve. This is the
## spatial vs non-spatial within-LANDIS structural comparison (same calibrated params, same
## TreeMap-derived initial communities, same reserve = no harvest/no disturbance; the only
## difference is landscape-spatial vs independent-plot simulation).
##
## Both are anchored to the SAME FIA 2025 design total, so 2025 matches by construction and
## the divergence by 2100 isolates the spatial-structure effect.
##
## Inputs:
##   RUN/outputs/biomass/biomass-{species}-{timestep}.tif  (g/m2 live AGB per species per 5yr)
##   landis_ME_reserve.csv (per-plot reserve, agc_MgC_ha by year)
##   fia_agc_anchor_design_by_state.csv (ME design total + cv)
## Output: landis_ME_spatial_vs_plot.csv + console comparison.
## module load gcc/12.3.0 gdal R/4.4.0  (terra, data.table)
suppressPackageStartupMessages({library(terra); library(data.table)})
RUN <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states/ME/runs/maine_fullstate_reserve"
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
BIO <- file.path(RUN, "outputs/biomass")
SPP <- c("BF","SM","BE","RS","WS","BS","CE","YB","RM","IH","PINE","ASH","HE")  # the deck species
STEP_YRS <- 5; START_YR <- 2025

tifs <- list.files(BIO, pattern="^biomass-.*\\.tif$", full.names=TRUE)
if (!length(tifs)) stop("no biomass rasters yet - run still in progress")
# timesteps present (from biomass-<species>-<ts>.tif)
ts <- sort(unique(as.integer(sub(".*-(\\d+)\\.tif$","\\1",basename(tifs)))))

spatial <- rbindlist(lapply(ts, function(t){
  # sum live-species AGB per cell (skip dead pools), mean over forested (non-NA, >0) cells
  layers <- file.path(BIO, sprintf("biomass-%s-%d.tif", SPP, t))
  layers <- layers[file.exists(layers)]
  if (!length(layers)) return(NULL)
  s <- rast(layers); tot <- sum(s, na.rm=TRUE)            # g/m2 summed over species
  v <- values(tot, na.rm=TRUE); v <- v[v>0]
  agb_gm2 <- mean(v)                                       # mean live AGB g/m2 over forest
  data.table(year = START_YR + STEP_YRS*t,
             agc_MgC_ha = agb_gm2 * 0.01 * 0.5)            # g/m2 -> Mg/ha (*0.01) -> C (*0.5)
}))[order(year)]

anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[state=="ME"]
base <- spatial[year==START_YR]$agc_MgC_ha
if (!length(base)) base <- spatial$agc_MgC_ha[1]
spatial[, agc_TgC_anchored := anc$agc_TgC_design * agc_MgC_ha / base]
spatial[, mode := "spatial_landscape"]

plt <- fread(file.path(FIA,"landis_ME_reserve.csv"))
plt <- plt[, .(agc_MgC_ha = mean(agc_MgC_ha)), by=year][order(year)]
pbase <- plt[year==START_YR]$agc_MgC_ha; if(!length(pbase)) pbase <- plt$agc_MgC_ha[1]
plt[, agc_TgC_anchored := anc$agc_TgC_design * agc_MgC_ha / pbase][, mode:="per_plot"]

out <- rbind(spatial[,.(year,mode,agc_MgC_ha,agc_TgC_anchored)],
             plt[,.(year,mode,agc_MgC_ha,agc_TgC_anchored)])
fwrite(out, file.path(FIA,"landis_ME_spatial_vs_plot.csv"))

cat("Maine LANDIS reserve: spatial-landscape vs per-plot (anchored Tg C)\n")
cmp <- dcast(out, year~mode, value.var="agc_TgC_anchored")
cmp[, pct_diff := round(100*(spatial_landscape-per_plot)/per_plot,1)]
print(cmp)
cat("\nInterpretation: 2025 matches (same anchor). The 2100 gap is the spatial-structure\n")
cat("effect (neighborhood seed dispersal, ecoregion climate, landscape competition) vs\n")
cat("independent-plot simulation. Both share calibrated params + TreeMap initial communities.\n")
