## s43 Track B: round trip check per stratum (forest type classifier ft) and pseudo-age, from pass 0 verification of s43nd_build_v1.py
suppressMessages(library(data.table)); T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver"; OD <- file.path(T, "out/rt_eval"); dir.create(OD, showWarnings = FALSE)
FTM <- list(NH = c(FT100 = "WRPH", FT120 = "SF", FT160 = "WRPH", FT400 = "OAK", FT500 = "OAK", FT700 = "MBB", FT800 = "MBB", FT900 = "AB"),
  VT = c(FT100 = "WRPH", FT120 = "SF", FT380 = "SF", FT400 = "OAK", FT500 = "OAK", FT700 = "MBB", FT800 = "MBB", FT900 = "AB"),
  MI = c(FT100 = "WRPH", FT120 = "SF", FT200 = "SF", FT260 = "SF", FT380 = "WRPH", FT400 = "OAK", FT500 = "OAK", FT700 = "EAC", FT800 = "MBB", FT900 = "AB"),
  WI = c(FT100 = "WRPH", FT120 = "SF", FT260 = "SF", FT380 = "WRPH", FT400 = "OAK", FT500 = "OAK", FT700 = "EAC", FT800 = "MBB", FT900 = "AB"),
  MN = c(FT100 = "WRPH", FT120 = "SF", FT380 = "WRPH", FT400 = "OAK", FT500 = "OAK", FT700 = "EAC", FT800 = "MBB", FT900 = "AB"),
  ME = c(FT100 = "WRPH", FT120 = "SF", FT160 = "WRPH", FT380 = "SF", FT400 = "OAK", FT500 = "OAK", FT700 = "EAC", FT800 = "MBB", FT900 = "AB"))
TYP <- function(ft) as.integer(sub("FT", "", ft))
AA <- fread(file.path(T, "out/pseudo/tb_pseudoage_age_area_DATA.csv"))
R <- rbindlist(lapply(names(FTM), function(S) { f <- file.path(T, "out/rt", S, paste0("s43nd_", S, "_roundtrip_all_passes_20261019.csv")); cat("md5", tools::md5sum(f), f, "\n")
  d <- fread(f)[pass == 0]; d[, st := S]; d }))
R[, err := abs(ratio - 1)]; R[, cls := cut(age, seq(0, 200, 10), labels = paste0(seq(1, 191, 10), "-", seq(10, 200, 10)))]
## pseudo-age area by type group and integer age; a type classifier is occupied at an age where its group has pseudo-age area
R <- merge(R, AA[age_int <= 200, .(st, group = grp, age = age_int, area_ha)], by = c("st", "group", "age"), all.x = TRUE)
R[is.na(area_ha), area_ha := 0]
ALL <- R[, .(max_err_pct_1_200 = 100 * max(err), n_ages_over_2pct_1_200 = sum(err > 0.02), max_err_pct_20_150 = 100 * max(err[age >= 20 & age <= 150]),
  max_err_pct_occupied = if (any(area_ha > 0)) 100 * max(err[area_ha > 0]) else NA_real_, n_occ_ages_over_2pct = sum(err > 0.02 & area_ha > 0),
  ages_over_2pct = paste(range(age[err > 0.02]), collapse = "-"), occ_ages_over_2pct = if (any(err > 0.02 & area_ha > 0)) paste(age[err > 0.02 & area_ha > 0], collapse = " ") else ""), by = .(st, ft, group)]
ALL[, pass_occupied_2pct := n_occ_ages_over_2pct == 0][, pass_all_ages_2pct := n_ages_over_2pct_1_200 == 0]
fwrite(ALL, file.path(OD, "tb_roundtrip_by_stratum_DATA.csv"))
CL <- R[, .(max_err_pct = 100 * max(err), group_pseudo_area_ha = sum(area_ha), occupied = any(area_ha > 0)), by = .(st, ft, group, cls)][, pass_2pct := max_err_pct <= 2]
fwrite(CL, file.path(OD, "tb_roundtrip_by_stratum_ageclass_DATA.csv"))
FAIL <- CL[pass_2pct == FALSE]; fwrite(FAIL, file.path(OD, "tb_roundtrip_failures_DATA.csv"))
print(ALL[, .(st, ft, group, mx = round(max_err_pct_1_200, 2), occ = round(max_err_pct_occupied, 2), n_occ_fail = n_occ_ages_over_2pct, fail_ages = ages_over_2pct)][n_occ_fail > 0 | mx > 2])
cat("strata", nrow(ALL), "pass occupied", sum(ALL$pass_occupied_2pct), "; class cells", nrow(CL), "fail", nrow(FAIL), "fail occupied", nrow(FAIL[occupied == TRUE]), "\n")
