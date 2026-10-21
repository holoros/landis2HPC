#!/usr/bin/env Rscript
# s41 step A3 diagnostic: completeness of GRM MIDPT and BEGIN biomass by
# component for NH (counts and sums only).
suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data"); st <- "NH"
f <- function(tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
gc_ <- fread(f("TREE_GRM_COMPONENT"), select = c("TRE_CN","SUBP_COMPONENT_AL_FOREST","SUBP_TPAGROW_UNADJ_AL_FOREST","SUBP_TPAMORT_UNADJ_AL_FOREST"), colClasses = list(character = "TRE_CN"))
setnames(gc_, c("TRE_CN","comp","tg","tm"))
be <- fread(f("TREE_GRM_BEGIN"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(be, 2, "b")
mi <- fread(f("TREE_GRM_MIDPT"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(mi, 2, "m")
x <- mi[be[gc_, on = "TRE_CN"], on = "TRE_CN"]
print(x[, .(n = .N, tg_pos = sum(tg > 0, na.rm = TRUE), tm_pos = sum(tm > 0, na.rm = TRUE),
            b_na = sum(is.na(b)), m_na = sum(is.na(m)), sum_tm_m = sum(tm * m, na.rm = TRUE),
            sum_tm_b = sum(tm * b, na.rm = TRUE)), by = comp])
cat(sprintf("rows in BEGIN %d MIDPT %d COMPONENT %d\n", nrow(be), nrow(mi), nrow(gc_)))
