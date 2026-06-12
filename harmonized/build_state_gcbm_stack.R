#!/usr/bin/env Rscript
## build_state_gcbm_stack.R - state-generalized GCBM source-raster builder.
## Generalized from build_maine_gcbm_stack.R: clips the CONUS TreeMap 2022 to ANY state,
## joins the VAT + FIA COND (STDAGE) + EPA L3 ecoregion + LCMS 2022 disturbance, and writes
## the per-state source stack GCBM's build_inputs.sh tiles. This is the enabler for the full
## CONUS GCBM spatial run: loop states -> stack -> tile -> array -> retain.
##
## Usage:  Rscript build_state_gcbm_stack.R <ST>          # e.g. MN
## Outputs: ~/cbm_maine/data/processed/gcbm_rasters_2022_<ST>/<st>_{mask,treemap_tmid,
##          fortypcd,stdage,balive,dombio_l,carbon_l,ecoregion_l3,lcms_cause_2022}.tif
## module load gcc/12.3.0 R/4.4.0  (terra, sf, foreign, data.table, readr)
suppressPackageStartupMessages({library(terra); library(sf); library(data.table)
  library(foreign); library(readr)})
sf::sf_use_s2(FALSE)
args <- commandArgs(trailingOnly = TRUE)
ST   <- toupper(args[1]); stopifnot(nchar(ST) == 2)
st   <- tolower(ST)
ROOT <- "/users/PUOM0008/crsfaaron"
out_dir <- file.path(ROOT, "cbm_maine/data/processed", sprintf("gcbm_rasters_2022_%s", ST))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
pf <- function(name) file.path(out_dir, sprintf("%s_%s", st, name))   # state-prefixed path

cat("== GCBM source stack for", ST, "==\n")
tm <- rast(file.path(ROOT, "TREEMAP/TM2022/TreeMap2022_CONUS.tif"))
states <- st_read(file.path(ROOT, "Disturbance/cb_2023_us_state_20m.shp"), quiet = TRUE)
s <- states[states$STUSPS == ST, ]; stopifnot(nrow(s) == 1)
s_proj <- st_transform(s, crs(tm)); s_vect <- vect(s_proj)
buf <- terra::buffer(s_vect, width = 1000)
tm_s <- mask(crop(tm, ext(buf), snap = "out"), s_vect); names(tm_s) <- "tmid"
writeRaster(tm_s, pf("treemap_tmid.tif"), datatype = "INT4U", overwrite = TRUE,
            gdal = c("COMPRESS=LZW","TILED=YES"))
mask_ras <- tm_s; mask_ras[!is.na(mask_ras)] <- 1L; names(mask_ras) <- st
writeRaster(mask_ras, pf("mask.tif"), datatype = "INT1U", overwrite = TRUE,
            gdal = c("COMPRESS=LZW","TILED=YES"))

vat <- as.data.table(read.dbf(file.path(ROOT,"TREEMAP/TM2022/TreeMap2022_CONUS.tif.vat.dbf")))
setnames(vat, "Value", "tmid")
tmids <- sort(unique(values(tm_s, na.rm = TRUE)))
vat_s <- vat[tmid %in% tmids]
cat("  TM_IDs in", ST, ":", length(tmids), " VAT rows:", nrow(vat_s), "\n")

## STDAGE from this state's FIA COND (area-weighted plot mean); fall back to STANDHT, then 50.
cond_path <- file.path(ROOT, "fia_data", sprintf("%s_COND.csv", ST))
if (file.exists(cond_path)) {
  cond <- fread(cond_path, select = c("PLT_CN","CONDID","STDAGE","CONDPROP_UNADJ"))
  cond[, PLT_CN := as.numeric(PLT_CN)]
  page <- cond[!is.na(STDAGE) & STDAGE >= 0,
               .(STDAGE = weighted.mean(STDAGE, CONDPROP_UNADJ, na.rm = TRUE)), by = PLT_CN]
  vat_s[, PLT_CN := as.numeric(PLT_CN)]
  vat_s <- merge(vat_s, page, by = "PLT_CN", all.x = TRUE)
} else { cat("  WARN no COND for", ST, "- STANDHT/50 fallback only\n"); vat_s[, STDAGE := NA_real_] }
vat_s[is.na(STDAGE) & !is.na(STANDHT) & STANDHT > 0, STDAGE := pmin(200, round(STANDHT*1.4))]
vat_s[is.na(STDAGE), STDAGE := 50L]
write_csv(vat_s, pf("pixel_attributes.csv"))

rw <- function(field, name, dt) {
  rcl <- as.matrix(vat_s[, .(from = tmid, to = get(field))])
  r <- classify(tm_s, rcl, others = NA, right = NA); names(r) <- field
  writeRaster(r, pf(name), datatype = dt, overwrite = TRUE, gdal = c("COMPRESS=LZW","TILED=YES"))
}
rw("FORTYPCD","fortypcd.tif","INT2U"); rw("STDAGE","stdage.tif","INT2U")
rw("BALIVE","balive.tif","FLT4S");     rw("DRYBIO_L","dombio_l.tif","FLT4S")
rw("CARBON_L","carbon_l.tif","FLT4S")

## EPA L3 ecoregion: ALL codes intersecting the state (Maine special-cased 58/59/82; general = all)
eco <- st_read(file.path(ROOT,"Disturbance/us_eco_l3.shp"), quiet = TRUE)
eco$code <- as.integer(as.character(eco$US_L3CODE))
eco_v <- vect(st_transform(eco, crs(tm_s)))
eco_r <- mask(rasterize(eco_v, tm_s, field = "code"), mask_ras); names(eco_r) <- "ecoregion_l3"
writeRaster(eco_r, pf("ecoregion_l3.tif"), datatype = "INT2U", overwrite = TRUE,
            gdal = c("COMPRESS=LZW","TILED=YES"))

lcms <- rast(file.path(ROOT,"Disturbance/validation_data/LCMS_cause/LCMS_CONUS_v2024-10_Change_2022.tif"))
lcms_s <- project(crop(lcms, project(ext(tm_s), crs(tm_s), crs(lcms))), tm_s, method = "near")
lcms_s <- mask(lcms_s, mask_ras); names(lcms_s) <- "lcms_cause_2022"
writeRaster(lcms_s, pf("lcms_cause_2022.tif"), datatype = "INT1U", overwrite = TRUE,
            gdal = c("COMPRESS=LZW","TILED=YES"))

cat("\nDone. Stack ->", out_dir, "\n")
for (f in list.files(out_dir, pattern="\\.tif$", full.names=TRUE)) {
  r <- rast(f); cat(sprintf("  %-30s %dx%d\n", basename(f), nrow(r), ncol(r)))
}
