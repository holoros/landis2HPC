# s43 Track A steps 5 and 6 (generalized from anchor_ic_fourstate_20261006.R to a state list; plan gates new 19 Oct, frozen).
# Usage: Rscript preanchor_gates_anchor_s43.R ST ECO_TAG   (e.g. ME from270, MN from30)
# Pre-anchoring gates:
#   P1 alignment: TM clip, IC raster and ecoregion layer share CRS, extent, origin and resolution
#   P2 live basal area mapped >= 0.98 (TreeMap tree table live trees of TM_IDs on active cells, weighted by active pixel count)
#   P3 active area (IC > 0 and ecoregion coded) within 1 pct of the firebreather 7 Oct build: log unreachable -> PENDING, area reported
#   P4 pre-anchoring biomass shares by species group (LANDIS code) and by Level III ecoregion within 3 points of FIADB
#      (EVALID ST2401, live DRYBIO_AG on forest land, design-based; plot ecoregion from public fuzzed LAT/LON, server side only)
# Anchoring: scale = EVALIDator 2024 stock / in-state pre-anchoring IC total; A1 scale within 3 pct of firebreather (ME 1.372, MN 1.275);
#   A2 anchored total equals target to 0.1 pct; A3 MapCode set unchanged. Writes cohort_biomass_by_mapcode_fiadb.csv beside the raw table.
suppressMessages({library(terra); library(data.table)})
terraOptions(memfrac = 0.6, progress = 0)
a <- commandArgs(TRUE); ST <- a[1]; ETAG <- a[2]
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn"; L <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states"
FD <- "/users/PUOM0008/crsfaaron/fia_data"; O <- file.path(T, "out"); B <- file.path(T, "build", ST, "initial_communities")
TARGET <- c(ME = 762.4297, MN = 633.4494)[ST]; FB <- c(ME = 1.372, MN = 1.275)[ST]; EV <- c(ME = 232401, MN = 272401)[ST]
g <- list(); addg <- function(gate, value, thr, res, note = "") g[[length(g) + 1]] <<- data.table(state = ST, gate, value = as.character(value), threshold = thr, result = res, note)
cat(ST, ETAG, "\n")
tm <- rast(file.path(L, ST, "inputs", paste0(ST, "_TM_22.tif"))); levels(tm) <- NULL
ic <- rast(file.path(B, "initial-communities.tif")); er <- rast(file.path(O, sprintf("ecoregions_s43_%s_%s.tif", ST, ETAG)))
al <- sapply(list(ic = ic, eco = er), function(r) c(crs = same.crs(r, tm), ext = isTRUE(all.equal(as.vector(ext(r)), as.vector(ext(tm)), tolerance = 0)),
  origin = isTRUE(all.equal(origin(r), origin(tm), tolerance = 0)), res = isTRUE(all.equal(res(r), res(tm), tolerance = 0))))
print(al)
addg("P1 alignment", paste(sprintf("%s:%s", rep(colnames(al), each = 4), apply(expand.grid(rownames(al), colnames(al)), 1, function(z) al[z[1], z[2]])), collapse = " "),
     "all TRUE vs TM grid", if (all(al)) "PASS" else "FAIL", sprintf("TM %dx%d origin %.3f %.3f res %g", ncol(tm), nrow(tm), xmin(tm), ymax(tm), res(tm)[1]))
tv <- values(tm)[, 1]; iv <- values(ic)[, 1]; ev <- values(er)[, 1]
act <- !is.na(iv) & iv > 0 & !is.na(ev) & ev > 0
cell_m2 <- prod(res(tm)); act_km2 <- sum(act) * cell_m2 / 1e6
fp <- data.table(TM_ID = tv[act], MapCode = iv[act], eco = ev[act])[, .(npix = .N), by = .(TM_ID, MapCode, eco)]
rm(tv, iv, ev, act); gc()
addg("P3 active_area_km2", round(act_km2, 1), "within 1 pct of firebreather 7 Oct build", "PENDING", "firebreather log unreachable (down since 15 Oct)")
# P2 basal area mapped
trt <- fread("/users/PUOM0008/crsfaaron/TREEMAP/TM2022/TreeMap2022_CONUS_Tree_Table.csv", select = c("TM_ID", "PLT_CN", "STATUSCD", "TPA_UNADJ", "SPCD", "DIA"))
trt <- trt[TM_ID %in% fp$TM_ID & STATUSCD == 1]
e <- new.env(); sys.source(file.path(O, paste0("species_lookup_", ST, "_s43.R")), envir = e); lk <- as.data.table(e$SPECIES_LOOKUP)
np <- fp[, .(npix = sum(npix)), by = TM_ID]; trt <- merge(trt, np, by = "TM_ID")
trt[, ba := 0.005454154 * DIA^2 * TPA_UNADJ * npix]
bam <- trt[, sum(ba[SPCD %in% lk$SPCD], na.rm = TRUE) / sum(ba, na.rm = TRUE)]
addg("P2 live_BA_mapped", round(bam, 4), ">= 0.98", if (bam >= 0.98) "PASS" else "FAIL", "pixel weighted, TreeMap 2022 tree table")
um <- trt[!SPCD %in% lk$SPCD, .(ba = sum(ba, na.rm = TRUE)), by = SPCD][order(-ba)][1:5][, share := round(ba / trt[, sum(ba, na.rm = TRUE)], 4)]
cat("top unmapped SPCD by BA share:\n"); print(um[, .(SPCD, share)])
# age backstop diagnostic (builder step 4 behaviour)
cd <- fread(file.path(FD, paste0(ST, "_COND.csv")), select = c("PLT_CN", "CONDID", "STDAGE", "COND_STATUS_CD"))
c1 <- cd[CONDID == 1]; c1[, PLT_CN := as.character(PLT_CN)]; trt[, PLT_CN := as.character(PLT_CN)]
med_builder <- as.integer(median(pmax(c1$STDAGE, 1L, na.rm = TRUE), na.rm = TRUE))
med_forest <- as.integer(median(c1[COND_STATUS_CD == 1 & STDAGE > 0, STDAGE]))
bmatch <- trt[, sum(ba[PLT_CN %in% c1$PLT_CN], na.rm = TRUE) / sum(ba, na.rm = TRUE)]
addg("diag age_backstop", sprintf("BA share on plots matched to COND %.4f; builder median backstop %d yr; forest STDAGE>0 median %d yr", bmatch, med_builder, med_forest), "report", "INFO")
rm(trt); gc()
# IC biomass shares
cb <- fread(file.path(B, "cohort_biomass_by_mapcode.csv"))
mc <- fp[, .(npix = sum(npix)), by = .(MapCode, eco)]
x <- merge(mc, cb[, .(g = sum(CohortBiomass)), by = .(MapCode, SpeciesName)], by = "MapCode", allow.cartesian = TRUE)
x[, Tg := npix * cell_m2 * g / 1e12]
pre_tg <- x[, sum(Tg)]
ic_sp <- x[, .(ic_Tg = sum(Tg)), by = .(group = SpeciesName)]; ic_eco <- x[, .(ic_Tg = sum(Tg)), by = .(group = as.character(eco))]
# FIADB
A <- fread(file.path(FD, paste0(ST, "_POP_PLOT_STRATUM_ASSGN.csv")), select = c("PLT_CN", "STRATUM_CN", "EVALID"))[EVALID == EV]
ps <- fread(file.path(FD, paste0(ST, "_POP_STRATUM.csv")), select = c("CN", "EXPNS", "ADJ_FACTOR_MICR", "ADJ_FACTOR_SUBP", "ADJ_FACTOR_MACR"))
p <- fread(file.path(FD, paste0(ST, "_PLOT.csv")), select = c("CN", "MACRO_BREAKPOINT_DIA", "LAT", "LON"))
TR <- fread(file.path(FD, paste0(ST, "_TREE.csv")), select = c("PLT_CN", "CONDID", "STATUSCD", "SPCD", "DIA", "TPA_UNADJ", "DRYBIO_AG"))
a2 <- merge(A, ps, by.x = "STRATUM_CN", by.y = "CN")
TR <- TR[STATUSCD == 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ) & PLT_CN %in% a2$PLT_CN]
TR <- merge(TR, cd[COND_STATUS_CD == 1, .(PLT_CN, CONDID)], by = c("PLT_CN", "CONDID"))
TR <- merge(TR, a2, by = "PLT_CN"); TR <- merge(TR, p[, .(CN, MACRO_BREAKPOINT_DIA)], by.x = "PLT_CN", by.y = "CN", all.x = TRUE)
TR[, adj := fifelse(DIA < 5, ADJ_FACTOR_MICR, fifelse(!is.na(MACRO_BREAKPOINT_DIA) & DIA >= MACRO_BREAKPOINT_DIA, ADJ_FACTOR_MACR, ADJ_FACTOR_SUBP))]
TR[, Tg := DRYBIO_AG * TPA_UNADJ * adj * EXPNS * 0.45359237 / 1e9]
fia_tot <- TR[, sum(Tg)]
addg("diag fiadb_forest_live_agb_Tg", sprintf("%.4f (EVALIDator target %.4f, ratio %.5f)", fia_tot, TARGET, fia_tot / TARGET), "report", "INFO", paste("EVALID", EV))
TR <- merge(TR, lk[, .(SPCD, LANDIS)], by = "SPCD", all.x = TRUE); TR[is.na(LANDIS), LANDIS := "unmapped"]
pv <- p[CN %in% unique(TR$PLT_CN) & !is.na(LAT)]
pv[, eco := as.integer(extract(er, project(vect(pv, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(er)))[, 2])]
pv[is.na(eco) | eco == 0, eco := -1L]
TR <- merge(TR, pv[, .(PLT_CN = CN, eco)], by = "PLT_CN", all.x = TRUE); TR[is.na(eco), eco := -1L]
fsp <- TR[, .(fia_Tg = sum(Tg)), by = .(group = LANDIS)]; feco <- TR[, .(fia_Tg = sum(Tg)), by = .(group = as.character(eco))]
addg("diag fiadb_unmapped_share", round(fsp[group == "unmapped", sum(fia_Tg)] / fia_tot, 4), "report", "INFO", "share of FIADB live AGB on SPCD outside lookup")
addg("diag fiadb_outside_eco_share", round(feco[group == "-1", sum(fia_Tg)] / fia_tot, 4), "report", "INFO", "share on plots whose fuzzed location falls outside the ecoregion layer")
sh <- function(ic, fia, kind) {
  fia <- fia[!group %in% c("unmapped", "-1")]; z <- merge(ic, fia, by = "group", all = TRUE); z[is.na(z)] <- 0
  z[, `:=`(ic_share = ic_Tg / sum(ic_Tg), fia_share = fia_Tg / sum(fia_Tg))][, diff_pp := 100 * (ic_share - fia_share)][, kind := kind][, state := ST][]
}
s1 <- sh(ic_sp, fsp, "species_group"); s2 <- sh(ic_eco, feco, "ecoregion_L3")
shares <- rbind(s1, s2); fwrite(shares, file.path(O, sprintf("preanchor_shares_%s_s43.csv", ST)))
print(shares[, .(kind, group, ic_share = round(ic_share, 4), fia_share = round(fia_share, 4), diff_pp = round(diff_pp, 2))])
for (k in c("species_group", "ecoregion_L3")) { m <- shares[kind == k, max(abs(diff_pp))]; w <- shares[kind == k][which.max(abs(diff_pp)), group]
  addg(paste("P4 shares", k), sprintf("max |diff| %.2f pp (%s)", m, w), "<= 3 pp", if (m <= 3) "PASS" else "FAIL") }
# Anchoring
sc <- TARGET / pre_tg
cba <- copy(cb)[, CohortBiomass := pmax(1L, as.integer(round(CohortBiomass * sc)))]
new_tg <- merge(mc[, .(npix = sum(npix)), by = MapCode], cba[, .(g = sum(CohortBiomass)), by = MapCode], by = "MapCode")[, sum(npix * cell_m2 * g) / 1e12]
addg("diag preanchor_instate_Tg", round(pre_tg, 3), "report", "INFO", sprintf("active %.1f km2, mean %.1f Mg/ha", act_km2, pre_tg * 1e6 / (act_km2 * 100)))
addg("A1 scale_vs_firebreather", sprintf("%.5f vs %.3f (gap %.2f pct)", sc, FB, 100 * (sc / FB - 1)), "within 3 pct", if (abs(sc / FB - 1) <= 0.03) "PASS" else "FAIL-STOP")
addg("A2 anchored_total", sprintf("%.4f vs %.4f", new_tg, TARGET), "within 0.1 pct", if (abs(new_tg / TARGET - 1) < 0.001) "PASS" else "FAIL")
addg("A3 mapcodes_unchanged", nrow(cba) == nrow(cb) && setequal(cba$MapCode, cb$MapCode), "TRUE", if (nrow(cba) == nrow(cb)) "PASS" else "FAIL")
dst <- file.path(B, "cohort_biomass_by_mapcode_fiadb.csv"); if (file.exists(dst)) stop("exists ", dst)
fwrite(cba, dst); addg("diag anchored_table_md5", tools::md5sum(dst), "report", "INFO", dst)
G <- rbindlist(g); fwrite(G, file.path(O, sprintf("preanchor_gates_%s_s43.csv", ST))); print(G[, .(gate, value, result)])
fwrite(mc, file.path(O, sprintf("active_mapcode_eco_%s_s43.csv", ST)))
cat("PREANCHOR_DONE\n")
