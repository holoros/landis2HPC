#!/usr/bin/env Rscript
# stage1_gates.R: hard gates on the installed stage one 270 m L3 ecoregion rasters.
# Usage: Rscript stage1_gates.R <ST>
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
ST <- commandArgs(TRUE)[1]
p <- file.path(FB, "states", ST, "inputs", "ecoregions_l3_270m_20260928.tif")
r <- rast(p)
codes <- list(NH = c(58, 59), VT = c(58, 59, 83), MI = c(50, 51, 55, 56, 57), WI = c(47, 50, 51, 52, 53, 54))[[ST]]
poly <- state_poly(ST, crs(r))
cat("md5", tools::md5sum(p), p, "\n")
raster_gates(ST, "stage1", "eco270", r, poly, 270, min(codes), max(codes),
             inside_min = 0.98, inside_prov = "set here: 270 m edge cells vs 1:20M cartographic polygon",
             reach_min = 0.97, reach_prov = "stage one report coverage 0.977 to 1.000")
gate(ST, "stage1", "eco270:square_cells", abs(res(r)[1] - res(r)[2]) < 1e-6,
     sprintf("%.6f x %.6f", res(r)[1], res(r)[2]), "xres == yres", "LANDIS CellLength assumes square cells")
u <- sort(unique(r)[, 1])
gate(ST, "stage1", "eco270:codes_expected", setequal(u, codes), paste(u, collapse = " "), paste(codes, collapse = " "),
     "brief: stage one codes per state")
txt <- readLines(file.path(FB, "states", ST, "inputs", "ecoregions_candidate_20260928.txt"))
act <- as.integer(sapply(strsplit(grep("^yes", txt, value = TRUE), "\t"), `[`, 2))
gate(ST, "stage1", "eco270:table_matches_raster", setequal(act, u), paste(act, collapse = " "), "active MapCodes == raster codes",
     "LANDIS Ecoregions table must list every raster code")
nz <- global(r == 0, "sum", na.rm = TRUE)[1, 1]
gate(ST, "stage1", "eco270:no_zero_codes", nz == 0, paste("NAflag", NAflag(r), "zero cells", nz),
     "0 cells coded 0 (outside-state cells are NA)", "nothing uncovered silently becomes a valid code")
