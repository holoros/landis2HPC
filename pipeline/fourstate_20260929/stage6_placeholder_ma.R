#!/usr/bin/env Rscript
# stage6_placeholder_ma.R <ST>: PLACEHOLDER management-area table, landowner shares and README.
# Kevin Solarik's management-area definitions have not arrived. One statewide area (MapCode 1) covering
# every active IC cell; the raster itself is written by stage3_stands.R (management-area_PLACEHOLDER.tif).
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
ST <- commandArgs(TRUE)[1]; IN <- file.path(FB, "states", ST, "inputs"); SD <- file.path(FB, "states", ST)
mp <- file.path(IN, "management-area_PLACEHOLDER.tif")
M <- rast(mp); n <- global(M, "notNA")[1, 1]
H <- c("PLACEHOLDER: NOT the NCASI Phase II management areas. Kevin Solarik's definitions have not arrived (2026-09-29).",
       "PLACEHOLDER: any result produced from these inputs must be labelled placeholder.")
tp <- beside(file.path(IN, "management-areas_PLACEHOLDER.txt"))
writeLines(c(paste(">>", H), sprintf(">> %s single statewide management area on the 30 m IC grid (%s).", ST, basename(mp)),
             ">> Generated 2026-09-29 by scripts_20260929/stage6_placeholder_ma.R", "",
             ">> MapCode\tName\tActiveCells\tDescription",
             sprintf("1\tstatewide_PLACEHOLDER\t%d\t\"all active forest cells; no prescriptions assigned\"", n)), tp)
lp <- beside(file.path(IN, "landowner_shares_PLACEHOLDER.csv"))
writeLines(c(paste("#", H), "state,owner,cells,share", sprintf("%s,Statewide_PLACEHOLDER,%d,100.0", ST, n)), lp)
rp <- beside(file.path(SD, "README_PLACEHOLDER.txt"))
writeLines(c(H, "",
  sprintf("State: %s. Files in inputs/ carrying PLACEHOLDER in the name:", ST),
  "  management-area_PLACEHOLDER.tif   single statewide area (1 = active cell, 0 = nodata), 30 m IC grid",
  "  management-areas_PLACEHOLDER.txt  matching table (MapCode 1)",
  "  landowner_shares_PLACEHOLDER.csv  single owner class at 100 percent (template carries landowner_shares.csv)",
  "Replace all three when the management-area definitions arrive; do not report scenario results from them as final.",
  "Generated 2026-09-29, scripts_20260929/stage6_placeholder_ma.R"), rp)
gate(ST, "stage6", "placeholder_files_named", all(grepl("PLACEHOLDER", basename(c(mp, tp, lp, rp)))), paste(basename(c(mp, tp, lp, rp)), collapse = " "),
     "PLACEHOLDER in every filename", "brief")
hd <- c(readLines(tp, 1), readLines(lp, 1), readLines(rp, 1))
gate(ST, "stage6", "placeholder_in_headers", all(grepl("PLACEHOLDER", hd)), "first line of each text file", "contains PLACEHOLDER", "brief")
for (f in c(tp, lp, rp)) cat("md5", tools::md5sum(f), f, "\n")
