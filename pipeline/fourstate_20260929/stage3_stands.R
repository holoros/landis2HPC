#!/usr/bin/env Rscript
# stage3_stands.R: stands.tif on the 30 m initial-communities grid, following build_stands.sh
# (each forested cell with IC MapCode > 0 is its own stand, IDs 1..n, nodata 0), plus the stage six
# PLACEHOLDER statewide management-area raster (1 on every active cell, nodata 0) on the same grid.
# Also the 30 m IC gates and the cross-layer alignment gates. Usage: Rscript stage3_stands.R <ST> <IC_TIF> <IC_TXT>
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
a <- commandArgs(TRUE); ST <- a[1]; ICP <- a[2]; ICT <- a[3]
IN <- file.path(FB, "states", ST, "inputs")
ic <- rast(ICP); cat("IC", ICP, tools::md5sum(ICP), "\n")
# IC text: MapCodes defined
txt <- readLines(ICT); mcs <- as.integer(sub("^MapCode[ \t]+", "", grep("^MapCode", txt, value = TRUE)))
poly <- state_poly(ST, crs(ic))
raster_gates(ST, "stage3", "IC30", ic, poly, 30, 0, max(mcs),
             inside_min = 0.0, inside_prov = "bbox IC by design (build_initial_communities_v3.R writes the whole TreeMap clip); informational",
             reach_min = 0.999, reach_prov = "state polygon inside IC extent", reach_mode = "extent")
u <- unique(ic)[, 1]; u <- u[!is.na(u) & u > 0]
gate(ST, "stage3", "IC30:codes_defined_in_txt", all(u %in% mcs), sprintf("%d raster codes, %d undefined", length(u), sum(!u %in% mcs)),
     "0 undefined", "every raster MapCode needs an Initial Communities entry")
tm <- rast(file.path(IN, paste0(ST, "_TM_22.tif")))
gate(ST, "stage3", "IC30:same_grid_as_TM_22", compareGeom(ic, tm, stopOnError = FALSE), "compareGeom", "identical grid", "IC is a reclass of the TreeMap clip")
# nodata: TreeMap NA must stay NA (never a valid MapCode); TM forest cells with no mapped cohorts become 0
bad <- global(ifel(is.na(tm) & !is.na(ic) & ic > 0, 1, NA), "sum", na.rm = TRUE)[1, 1]
gate(ST, "stage3", "IC30:no_code_on_TM_nodata", is.na(bad) || bad == 0, ifelse(is.na(bad), 0, bad), "0 cells", "nothing uncovered silently becomes a valid code")
z <- global(ifel(!is.na(tm) & ic == 0, 1, NA), "sum", na.rm = TRUE)[1, 1]
nf <- global(ifel(!is.na(tm), 1, NA), "sum", na.rm = TRUE)[1, 1]
gate(ST, "stage3", "IC30:forest_cells_without_cohorts", TRUE, sprintf("%s of %s TM forest cells -> MapCode 0 (%.4f)", z, nf, ifelse(is.na(z), 0, z) / nf),
     "reported", "informational: TM_IDs whose trees are all unmapped or absent")
# stands (build_stands.sh semantics)
sp <- beside(file.path(IN, "stands.tif"))
v <- values(ic, mat = FALSE); act <- which(!is.na(v) & v > 0)
s <- rast(ic); sv <- integer(length(v)); sv[act] <- seq_along(act)
values(s) <- sv; rm(sv); gc()
writeRaster(s, sp, datatype = "INT4S", NAflag = 0, overwrite = FALSE, gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES"))
rm(s); gc()
mp <- beside(file.path(IN, "management-area_PLACEHOLDER.tif"))
m <- rast(ic); mv <- integer(length(v)); mv[act] <- 1L; values(m) <- mv; rm(mv); gc()
writeRaster(m, mp, datatype = "INT4S", NAflag = 0, overwrite = FALSE, gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES"))
rm(m, v); gc()
S <- rast(sp); M <- rast(mp)
cat("stands", sp, tools::md5sum(sp), "\nmanagement-area PLACEHOLDER", mp, tools::md5sum(mp), "\n")
gate(ST, "stage3", "stands:same_grid_as_IC", compareGeom(S, ic, stopOnError = FALSE), "compareGeom", "identical grid", "LANDIS reads stands with IC")
gate(ST, "stage6", "MA_PLACEHOLDER:same_grid_as_IC", compareGeom(M, ic, stopOnError = FALSE), "compareGeom", "identical grid", "LANDIS reads management areas with IC")
mmS <- minmax(S, compute = TRUE); mmM <- minmax(M, compute = TRUE)
gate(ST, "stage3", "stands:range", mmS[1] >= 1 && mmS[2] == length(act), paste(mmS, collapse = " "), paste("[1,", length(act), "]"), "one stand per active cell")
gate(ST, "stage6", "MA_PLACEHOLDER:range", mmM[1] == 1 && mmM[2] == 1, paste(mmM, collapse = " "), "[1,1]", "single statewide PLACEHOLDER area")
nS <- global(S, "notNA")[1, 1]; nM <- global(M, "notNA")[1, 1]
gate(ST, "stage3", "stands:active_equals_IC_active", nS == length(act) && nM == length(act), sprintf("stands %s, MA %s, IC>0 %s", nS, nM, length(act)),
     "equal", "active cells identical across IC, stands, MA")
e1 <- stage1_eco(ST)
gate(ST, "stage3", "IC30:same_grid_as_stage1_ecoregions", compareGeom(ic, e1, stopOnError = FALSE),
     sprintf("IC 30 m origin %.3f,%.3f vs stage1 res %.3fx%.3f", xmin(ic), ymax(ic), res(e1)[1], res(e1)[2]), "identical grid",
     "LANDIS reads ecoregions with IC; stage one raster is 270 m non-square (see stage1 gates)")
cat("stage3 stands/MA done", ST, "\n")
