## s41 cbm_fvsrecal: compare rebuilt sit_yield files against reference files.
## usage: Rscript s41cf_cmp_sityield_v1.R NEWDIR REFPATTERN OUTCSV  (REFPATTERN contains %s for state)
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); res <- list()
for (st in c("ME", "NH", "VT", "MI", "WI", "MN")) {
  n <- fread(file.path(a[1], sprintf("sit_yield_%s_calibrated.csv", st))); r <- fread(sprintf(a[2], st))
  m <- merge(r, n, by = c("TYPGRPCD", "stand_age"), suffixes = c(".r", ".n"), all = TRUE)
  res[[st]] <- data.table(state = st, rows_ref = nrow(r), rows_new = nrow(n), unmatched = sum(is.na(m$vol_m3_ha.r) | is.na(m$vol_m3_ha.n)),
    groups_ref = uniqueN(r$TYPGRPCD), groups_new = uniqueN(n$TYPGRPCD),
    max_abs_diff_m3ha = max(abs(m$vol_m3_ha.r - m$vol_m3_ha.n), na.rm = TRUE),
    md5_ref = unname(tools::md5sum(sprintf(a[2], st))), md5_new = unname(tools::md5sum(file.path(a[1], sprintf("sit_yield_%s_calibrated.csv", st)))))
}
R <- rbindlist(res); R[, byte_identical := md5_ref == md5_new]; print(R); fwrite(R, a[3])
