#!/usr/bin/env Rscript
# stage3_cond_merge.R: minimal COND table (PLT_CN, CONDID, STDAGE) across all 48 CONUS state COND files,
# because TreeMap 2022 imputes plots from any state; a state-only COND leaves out-of-state plots on the
# median-age backstop. No coordinates (COND carries none). Output stays under ~/restricted.
suppressPackageStartupMessages(library(data.table))
D <- path.expand("~/restricted/ncasi-modeleval/fia_data_landis/cond_all")
out <- path.expand("~/restricted/ncasi-modeleval/fia_data_landis/COND_CONUS_min_20260929.csv")
fs <- list.files(D, "_COND[.]csv$", full.names = TRUE)
L <- lapply(fs, function(f) fread(f, select = c("PLT_CN", "CONDID", "STDAGE"), colClasses = list(character = "PLT_CN")))
X <- unique(rbindlist(L))
fwrite(X, out)
cat("files", length(fs), "rows", nrow(X), "plots", uniqueN(X$PLT_CN), "\n", out, tools::md5sum(out), "\n")
