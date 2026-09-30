#!/usr/bin/env Rscript
# LANDIS-II four-state build, stage one: EPA Level III ecoregion rasters for NH, VT, MI, WI
# on firebreather (28 Sep 2026). Port of landis2/tools/clip_state_ecoregions.R with paths
# made local and gates added. Maine already has its 270 m unmasked raster (session 29).
#
# Writes, per state, into out/<ST>/:
#   ecoregions_l3_270m_20260928.tif   INT4S, EPSG:5070, 270 m, US_L3CODE
#   ecoregions_candidate_20260928.txt LANDIS Ecoregions table, codes from the raster
#   stage1_report_<ST>.txt            gate results
# Nothing is written over an existing installed file; products are candidates.
#
# Pre-registered gates (F3 axes; thresholds from outside the artifact per F4):
#   G1 location   raster extent intersects the census state polygon
#   G2 coverage   raster area / census state polygon area in [0.97, 1.02]
#                 (the four unmasked states measured in session 29 ran 0.979 to 0.999)
#   G3 values     every raster value is a US_L3CODE present in the EPA polygons
#   G4 cross-layer every ecoregion code in the raster has parameter rows in the state's Dryad
#                 SppEcoregionData.csv (a mapped ecoregion with no parameters stops LANDIS);
#                 Dryad codes absent from the raster are reported, not failed.
#                 Revised 28 Sep after the first run: the gate was first written in the other
#                 direction and failed NH and VT on code 82, Acadian Plains and Hills, which is
#                 Maine-only in EPA Level III. Those Dryad files were copied from Maine's
#                 (session 26 found NH byte identical to Maine), so the extra 82 rows are an
#                 inheritance artifact, not a raster defect.
# Usage: source ~/opt/geos/activate.sh; Rscript landis_stage1_ecoregions_20260928.R NH VT MI WI
suppressPackageStartupMessages(library(terra))
sts <- commandArgs(TRUE)
J <- "~/jobs/landis_stage1_20260928"
states <- vect(file.path(J, "gis/cb_2023_us_state_20m.shp"))
eco <- vect(file.path(J, "gis/us_eco_l3.shp"))
names_l3 <- unique(data.frame(code = as.integer(eco$US_L3CODE), name = eco$US_L3NAME))
fail <- 0
for (ST in sts) {
  out <- file.path(J, "out", ST); dir.create(out, recursive = TRUE, showWarnings = FALSE)
  rep <- file.path(out, sprintf("stage1_report_%s.txt", ST))
  msg <- function(...) { s <- sprintf(...); cat(s, "\n"); cat(s, "\n", file = rep, append = TRUE) }
  if (file.exists(rep)) file.remove(rep)
  res <- try({
    poly <- states[states$STUSPS == ST, ]
    if (nrow(poly) != 1) stop("state polygon not found for ", ST)
    eco_st <- crop(eco, project(poly, crs(eco)))
    eco_st$L3 <- as.integer(eco_st$US_L3CODE)
    e5070 <- project(eco_st, "EPSG:5070")
    p5070 <- project(poly, "EPSG:5070")
    tmpl <- rast(ext(e5070), resolution = 270, crs = "EPSG:5070")
    r <- rasterize(e5070, tmpl, field = "L3")
    r <- mask(r, rasterize(p5070, tmpl))          # clip to the state, not the ecoregion bbox
    cand <- file.path(out, "ecoregions_l3_270m_20260928.tif.candidate")
    writeRaster(r, cand, filetype = "GTiff", datatype = "INT4S", overwrite = TRUE,
                gdal = c("COMPRESS=DEFLATE"))
    vals <- sort(unique(values(r, na.rm = TRUE)[, 1]))
    r_area <- sum(!is.na(values(r))) * 270^2 / 1e6
    p_area <- expanse(p5070, unit = "km")
    ratio <- r_area / p_area
    g1 <- relate(ext(r), ext(p5070), "intersects")
    g2 <- ratio >= 0.97 && ratio <= 1.02
    g3 <- all(vals %in% names_l3$code)
    spp <- file.path(J, "spp", sprintf("%s_SppEcoregionData.csv", ST))
    dry <- if (file.exists(spp)) sort(unique(as.integer(read.csv(spp)$EcoregionName))) else integer(0)
    g4 <- length(dry) > 0 && all(vals %in% dry)
    msg("%s raster %.0f km2, census polygon %.0f km2, ratio %.3f", ST, r_area, p_area, ratio)
    msg("%s L3 codes in raster: %s", ST, paste(vals, collapse = " "))
    msg("%s L3 codes in Dryad SppEcoregionData: %s", ST, paste(dry, collapse = " "))
    msg("%s codes in raster not in Dryad file: %s", ST, paste(setdiff(vals, dry), collapse = " "))
    msg("%s Dryad codes absent from raster (inherited rows, unused): %s", ST, paste(setdiff(dry, vals), collapse = " "))
    msg("%s gates: G1 location %s, G2 coverage %s, G3 values %s, G4 cross-layer %s",
        ST, g1, g2, g3, g4)
    if (!(g1 && g2 && g3 && g4)) stop("gate failure; candidate kept, not promoted")
    file.rename(cand, file.path(out, "ecoregions_l3_270m_20260928.tif"))
    tab <- names_l3[names_l3$code %in% vals, ]; tab <- tab[order(tab$code), ]
    lines <- c('LandisData\t"Ecoregions"', "", ">>Active\tMapCode\tName\tDescription",
               'no\t0\tnodata\t"non-forest"',
               sprintf('yes\t%d\t%d\t"%s"', tab$code, tab$code, tab$name))
    writeLines(lines, file.path(out, "ecoregions_candidate_20260928.txt"))
    msg("%s PROMOTED", ST)
  }, silent = TRUE)
  if (inherits(res, "try-error")) { fail <- fail + 1; msg("%s FAILED: %s", ST, conditionMessage(attr(res, "condition"))) }
  gc()
}
cat(if (fail) sprintf("done with %d failures\n", fail) else "done\n")
