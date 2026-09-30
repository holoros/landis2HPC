#!/usr/bin/env Rscript
# stage2_clip_treemap.R  (adapted from landis2/tools/clip_state_treemap.R for firebreather)
# Recipe encoded by clip_state_treemap.R: crop CONUS TreeMap 2022 to the extent of the state's
# ecoregion raster, padded 2 km, write <ST>_TM_22.tif (INT4U, DEFLATE, PREDICTOR=2, TILED).
# Differences: firebreather paths; reference extent = stage one 270 m L3 raster; mode verify checks an
# existing clip (NH) against a fresh TM2022 crop instead of rebuilding; hard gates added.
# Usage: Rscript stage2_clip_treemap.R <ST> [build|verify]
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
args <- commandArgs(TRUE); ST <- args[1]; MODE <- if (length(args) > 1) args[2] else "build"
IN <- file.path(FB, "states", ST, "inputs")
TM_CONUS <- file.path(FB, "TREEMAP", "TM2022", "TreeMap2022_CONUS.tif")
VAT      <- file.path(FB, "TREEMAP", "TM2022", "TreeMap2022_CONUS.tif.vat.dbf")
tm  <- rast(TM_CONUS)
ref <- stage1_eco(ST)
outp <- file.path(IN, paste0(ST, "_TM_22.tif"))
p <- project(as.polygons(ext(ref), crs = crs(ref)), crs(tm))
e <- ext(p); pad <- 2000
e_pad <- ext(xmin(e) - pad, xmax(e) + pad, ymin(e) - pad, ymax(e) + pad)
if (MODE == "build") {
  outp <- beside(outp)
  out <- crop(tm, e_pad)
  writeRaster(out, outp, datatype = "INT4U", overwrite = FALSE,
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES"))
  cat(sprintf("wrote %s: %d x %d, res %.0f m\n", outp, nrow(out), ncol(out), res(out)[1]))
} else {
  cat("VERIFY mode, existing raster not rebuilt:", outp, "\n")
  r0 <- rast(outp)
  fresh <- crop(tm, ext(r0))
  same_geom <- compareGeom(r0, fresh, stopOnError = FALSE)
  nd <- if (same_geom) global(ifel((r0 == fresh) | (is.na(r0) & is.na(fresh)), 0, 1), "sum", na.rm = TRUE)[1, 1] else NA
  gate(ST, "stage2", "TM_22:identical_to_TM2022_crop", same_geom && !is.na(nd) && nd == 0,
       sprintf("geom=%s ndiff=%s", same_geom, nd), "0 differing cells",
       "confirms the existing clip derives from TreeMap 2022 CONUS")
  gate(ST, "stage2", "TM_22:covers_stage1_padded_extent",
       xmin(r0) <= xmin(e_pad) + 30 && xmax(r0) >= xmax(e_pad) - 30 && ymin(r0) <= ymin(e_pad) + 30 && ymax(r0) >= ymax(e_pad) - 30,
       paste(round(as.vector(ext(r0))), collapse = ","), "extent >= stage1 extent + 2 km pad (30 m tolerance)",
       "clip_state_treemap.R recipe")
}
r <- rast(outp)
cat("md5", tools::md5sum(outp), outp, "\n")
cat("dims", nrow(r), "x", ncol(r), "ncell", ncell(r), "\n")
poly <- state_poly(ST, crs(r))
vat <- as.data.table(foreign::read.dbf(VAT, as.is = TRUE))
maxid <- max(vat$TM_ID)
raster_gates(ST, "stage2", "TM_22", r, poly, 30, 0, maxid,
             inside_min = 0.0, inside_prov = "bbox clip by design (clip_state_treemap.R); informational only",
             reach_min = 0.999, reach_prov = "state polygon must lie inside the TreeMap clip extent", reach_mode = "extent")
u <- unique(r)[, 1]; u <- u[!is.na(u) & u > 0]
orph <- sum(!u %in% vat$TM_ID)
gate(ST, "stage2", "TM_22:ids_in_VAT", orph == 0, sprintf("%d unique ids, %d orphans", length(u), orph),
     "0 orphans", "TreeMap2022_CONUS.tif.vat.dbf")
gate(ST, "stage2", "TM_22:nodata_flag", TRUE, paste("NAflag", NAflag(r)), "reported",
     "informational: cells outside the TreeMap forest mask are NA")
ev <- as.points(ref, na.rm = TRUE)
inext <- relate(ev, as.polygons(ext(r), crs = crs(r)), "within")[, 1]
gate(ST, "stage2", "TM_22:covers_stage1_eco", mean(inext) >= 1.0, sprintf("%.4f", mean(inext)), ">= 1.000",
     "every valid stage one 270 m ecoregion cell centre lies within the TreeMap clip")
pr <- rasterize(poly, r, field = 1)
n_forest_in <- global(mask(ifel(!is.na(r) & r > 0, 1, NA), pr), "sum", na.rm = TRUE)[1, 1]
tm_km2 <- n_forest_in * prod(res(r)) / 1e6
st_km2 <- expanse(poly, unit = "km")
gate(ST, "stage2", "TM_22:forest_area_lt_state_area", tm_km2 < st_km2, sprintf("%.0f km2 vs state %.0f km2", tm_km2, st_km2),
     "forest < state area", "sanity bound (brief)")
cond <- fread(file.path(path.expand("~/restricted/ncasi-modeleval/fia_data_landis"), paste0(ST, "_COND.csv")),
              select = c("STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "COND_STATUS_CD", "CONDPROP_UNADJ"))
cond[, pid := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
cond <- cond[INVYR < 9999]
last <- cond[, .(INVYR = max(INVYR)), by = pid][INVYR >= 2010]
cl <- cond[last, on = .(pid, INVYR)]
ff <- cl[COND_STATUS_CD == 1, sum(CONDPROP_UNADJ, na.rm = TRUE)] / cl[COND_STATUS_CD %in% 1:4, sum(CONDPROP_UNADJ, na.rm = TRUE)]
fia_km2 <- ff * st_km2
ratio <- tm_km2 / fia_km2
gate(ST, "stage2", "TM_22:forest_area_vs_FIA_order_of_magnitude", ratio > 0.5 && ratio < 2.0,
     sprintf("TM %.0f km2 / (FIA forest fraction %.3f x state %.0f km2 = %.0f km2) = %.2f", tm_km2, ff, st_km2, fia_km2, ratio), "(0.5, 2.0)",
     "band set here; FIA forest fraction = unweighted CONDPROP_UNADJ share of status-1 conditions, latest INVYR >= 2010 per plot, status 1-4 denominator")
cat("stage2 done", ST, "\n")
