## s41 cbm_fvsrecal: build the yield adapter input (fvs_growth_points shape) from
## FVS frame runner stand trajectories. No PLT_CN or coordinates are read or written
## (trajectory files carry anonymised stand ids only).
## usage: Rscript s41cf_points_v1.R OUT.csv REF_FOREST_TYPE.csv traj.csv:arm_in:arm_out [...]
## env AGECOL = age (FVS summary age, default) or offset (stand_age + year_offset)
## env COMPARE = existing points csv to compare against (optional)
## env LABELS = existing points csv whose per stand TYPGRPCD, forest_type_group and region
##   labels are used instead of REF_FOREST_TYPE (v2: the September labels, same anonymised stand ids)
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); OUT <- a[1]; REF <- fread(a[2])
ref <- unique(REF[, .(FORTYPCD = as.integer(VALUE), TYPGRPCD = as.integer(TYPGRPCD))])
gnm <- unique(REF[as.integer(VALUE) == as.integer(TYPGRPCD), .(TYPGRPCD = as.integer(TYPGRPCD), forest_type_group = MEANING)])
ST6 <- c("ME", "NH", "VT", "MI", "WI", "MN")
res <- list()
for (s in a[-(1:2)]) {
  p <- strsplit(s, ":")[[1]]
  d <- fread(p[1], select = c("stand_id", "state", "scenario", "arm", "year_offset", "stand_age", "age", "fortypcd",
                               "merch_vol_m3ha", "tot_vol_m3ha", "c_abg_live_MgCha"))
  d <- d[scenario == "no_harvest" & arm == p[2] & state %in% ST6 & year_offset <= 50]
  cat(sprintf("%s arm %s -> %s: %d rows, %d stands\n", basename(p[1]), p[2], p[3], nrow(d), uniqueN(d$stand_id)))
  d[, arm := p[3]]; res[[s]] <- d
}
d <- rbindlist(res)
cat("rows per stand table:\n"); print(table(d[, .N, by = .(stand_id, arm)]$N))
cat(sprintf("age vs stand_age+offset identical on %d of %d rows\n", sum(abs(d$age - (d$stand_age + d$year_offset)) < 1e-9), nrow(d)))
ac <- Sys.getenv("AGECOL", "age")
d[, sa := if (ac == "age") age else stand_age + year_offset]
d <- merge(d, ref, by.x = "fortypcd", by.y = "FORTYPCD", all.x = TRUE)
cat(sprintf("unmatched FORTYPCD rows: %d\n", sum(is.na(d$TYPGRPCD))))
d <- merge(d, gnm, by = "TYPGRPCD", all.x = TRUE)
d[, region := fifelse(state %in% c("ME", "NH", "VT"), "NE", "LS")]
lab <- Sys.getenv("LABELS", "")
if (nzchar(lab)) {
  L <- unique(fread(lab)[, .(state, stand_id, TYPGRPCD_L = TYPGRPCD, forest_type_group_L = forest_type_group, region_L = region)])
  stopifnot(!anyDuplicated(L[, .(state, stand_id)]))
  d <- merge(d, L, by = c("state", "stand_id"), all.x = TRUE)
  stopifnot(!anyNA(d$TYPGRPCD_L))
  x <- unique(d[, .(state, stand_id, fortypcd, TYPGRPCD, TYPGRPCD_L, forest_type_group, forest_type_group_L)])
  cat("label crosswalk where REF and September labels differ (stand counts):\n")
  print(x[TYPGRPCD != TYPGRPCD_L | forest_type_group != forest_type_group_L, .N, by = .(fortypcd, ref_grp = TYPGRPCD, sept_grp = TYPGRPCD_L, ref_name = forest_type_group, sept_name = forest_type_group_L)])
  d[, `:=`(TYPGRPCD = TYPGRPCD_L, forest_type_group = forest_type_group_L, region = region_L)]
}
P <- d[, .(region, state, arm, TYPGRPCD, forest_type_group, stand_id, stand_age = sa, merch_vol_m3ha, tot_vol_m3ha, c_abg_live_MgCha)]
setorder(P, state, arm, stand_id, stand_age)
fwrite(P, OUT)
cat(sprintf("wrote %s: %d rows, %d stands\n", OUT, nrow(P), uniqueN(P[, paste(arm, stand_id)])))
cmp <- Sys.getenv("COMPARE", "")
if (nzchar(cmp)) {
  O <- fread(cmp)
  cat(sprintf("compare: new %d rows, old %d rows\n", nrow(P), nrow(O)))
  m <- merge(O, P, by = c("state", "arm", "stand_id", "stand_age"), suffixes = c(".o", ".n"), all = TRUE)
  cat(sprintf("only in old %d, only in new %d\n", sum(is.na(m$merch_vol_m3ha.n)), sum(is.na(m$merch_vol_m3ha.o))))
  for (v in c("merch_vol_m3ha", "tot_vol_m3ha", "c_abg_live_MgCha"))
    cat(sprintf("max abs diff %s: %.3g\n", v, max(abs(m[[paste0(v, ".o")]] - m[[paste0(v, ".n")]]), na.rm = TRUE)))
  cat(sprintf("TYPGRPCD mismatches %d, group name mismatches %d, region mismatches %d\n",
      sum(m$TYPGRPCD.o != m$TYPGRPCD.n, na.rm = TRUE), sum(m$forest_type_group.o != m$forest_type_group.n, na.rm = TRUE),
      sum(m$region.o != m$region.n, na.rm = TRUE)))
}
