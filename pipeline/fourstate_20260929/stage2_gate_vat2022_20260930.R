# Session 32: the 29 Sep stage two gate TM_22:ids_in_VAT failed with every id an orphan. Recheck against the 2022 VAT.
source("~/landis2_fb/scripts_20260929/gates_lib.R"); library(foreign)
vat <- read.dbf("~/landis2_fb/TREEMAP/TM2022/TreeMap2022_CONUS.tif.vat.dbf", as.is = TRUE)
cat("VAT columns:", names(vat), "\n"); idc <- names(vat)[1]
vid <- as.integer(vat[[idc]])
for (ST in c("NH","VT","MI","WI")) {
  r <- rast(file.path(FB, "states", ST, "inputs", paste0(ST, "_TM_22.tif"))); levels(r) <- NULL  # strip the RAT so unique() returns cell values, not ForTypName labels (the 29 Sep gate compared labels)
  u <- as.integer(na.omit(unique(r)[[1]])); u <- u[u > 0]; orphan <- setdiff(u, vid)
  gate(ST, "stage2", "TM_22:ids_in_VAT_2022", length(orphan) == 0, sprintf("%d unique ids, %d not in %s of the 2022 VAT", length(u), length(orphan), idc), "0 orphans", "TreeMap2022_CONUS.tif.vat.dbf Value column; the 29 Sep gate compared RAT labels with TM_ID")
}
