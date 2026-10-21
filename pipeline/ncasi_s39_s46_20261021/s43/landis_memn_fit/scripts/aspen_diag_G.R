# Track G step 2: aspen (QA) share diagnosis. Decomposes the pre-anchoring IC vs FIADB species-share gap into stages, pixel weighted
# on active cells (IC > 0 and ecoregion coded) of the Track A (original rule) build:
#  S_F  : TreeMap pixel assignment x FIADB tree DRYBIO_AG * TPA_UNADJ (trees joined by plot, subplot, tree number) -> isolates TreeMap assignment
#  S_T  : builder allocation of DBF plot DRYBIO_L by DIA_cm^2.5 * TPA_UNADJ (TPA weighted)
#  S_B  : builder allocation as coded (DIA_cm^2.5 per tree record, no TPA), per TM_ID
#  S_IC : builder output cohort_biomass_by_mapcode.csv (MapCode means) x MapCode pixels (reproduces Track A preanchor ic_share)
#  FIA  : Track A preanchor fia_share (EVALID design based)
# Plus lookup check for Populus SPCDs. Aggregates only; no plot identifiers written.
suppressMessages({library(terra); library(data.table)}); terraOptions(memfrac = 0.6, progress = 0)
ST <- commandArgs(TRUE)[1]; ETAG <- c(ME = "from270", MN = "from30")[ST]
G <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit"; SA <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn"
L <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states"; FD <- "/users/PUOM0008/crsfaaron/fia_data"; O <- file.path(G, "out")
B <- file.path(SA, "build", ST, "initial_communities")
NB <- list(MN = c("MN", "WI", "MI", "ND", "SD", "IA"), ME = c("ME", "NH", "VT", "NY", "MA"))[[ST]]
tm <- rast(file.path(L, ST, "inputs", paste0(ST, "_TM_22.tif"))); levels(tm) <- NULL
ic <- rast(file.path(B, "initial-communities.tif")); er <- rast(file.path(O, sprintf("ecoregions_s43_%s_%s.tif", ST, ETAG)))
tv <- values(tm)[, 1]; iv <- values(ic)[, 1]; ev <- values(er)[, 1]
act <- !is.na(iv) & iv > 0 & !is.na(ev) & ev > 0
px <- data.table(TM_ID = tv[act], MapCode = iv[act])[, .(npix = .N), by = .(TM_ID, MapCode)]; rm(tv, iv, ev, act); gc()
cat(ST, "active pixels", px[, sum(npix)], "TM_IDs", uniqueN(px$TM_ID), "\n")
e <- new.env(); sys.source(file.path(O, paste0("species_lookup_", ST, "_s43.R")), envir = e); lk <- as.data.table(e$SPECIES_LOOKUP)[, .(SPCD, LANDIS)]
tt <- fread("/users/PUOM0008/crsfaaron/TREEMAP/TM2022/TreeMap2022_CONUS_Tree_Table.csv", select = c("TM_ID", "PLT_CN", "STATUSCD", "TPA_UNADJ", "SPCD", "DIA", "SUBP", "TREE"))
tt <- tt[TM_ID %in% px$TM_ID & STATUSCD == 1]; tt[, PLT_CN := as.character(PLT_CN)]
tt <- merge(tt, lk, by = "SPCD", all.x = TRUE)
np <- px[, .(npix = sum(npix)), by = TM_ID]; tt <- merge(tt, np, by = "TM_ID")
dbf <- as.data.table(vect("/users/PUOM0008/crsfaaron/TREEMAP/TM2022/TreeMap2022_CONUS.tif.vat.dbf"))[TM_ID %in% px$TM_ID, .(TM_ID, DRYBIO_L)]
dbf[, g_m2 := DRYBIO_L * 2000 * 0.45359237 / 0.40468564 / 10]; dbf <- dbf[is.finite(g_m2) & g_m2 > 0]
# FIADB tree biomass for TreeMap trees
fb <- rbindlist(lapply(NB, function(s) { x <- fread(file.path(FD, paste0(s, "_TREE.csv")), select = c("PLT_CN", "SUBP", "TREE", "STATUSCD", "DRYBIO_AG", "TPA_UNADJ"))
  x[, PLT_CN := as.character(PLT_CN)]; x[PLT_CN %in% tt$PLT_CN & STATUSCD == 1, .(PLT_CN, SUBP, TREE, DRYBIO_AG, TPA_F = TPA_UNADJ)] }))
fb <- unique(fb, by = c("PLT_CN", "SUBP", "TREE"))
tt <- merge(tt, fb, by = c("PLT_CN", "SUBP", "TREE"), all.x = TRUE)
tt[, DIA_CM := DIA * 2.54][, w := pmax(DIA_CM, 0.1)^2.5]
cov_tree <- tt[, mean(!is.na(DRYBIO_AG))]; cov_pix <- tt[, sum(npix * (!is.na(DRYBIO_AG)) * w * TPA_UNADJ) / sum(npix * w * TPA_UNADJ)]
cat(sprintf("FIADB match: tree records %.4f; pixel x TPA x DIA^2.5 weighted %.4f\n", cov_tree, cov_pix))
m <- tt[!is.na(LANDIS)]
# S_F: plots with complete FIADB match only
okp <- tt[, .(ok = all(!is.na(DRYBIO_AG))), by = TM_ID][ok == TRUE, TM_ID]
SF <- m[TM_ID %in% okp, .(v = sum(npix * DRYBIO_AG * TPA_F)), by = .(group = LANDIS)]
alloc <- function(wcol) { z <- m[TM_ID %in% dbf$TM_ID]; z[, ww := get(wcol)]
  z[, f := ww / sum(ww), by = TM_ID]; z <- merge(z, dbf[, .(TM_ID, g_m2)], by = "TM_ID"); z[, .(v = sum(npix * g_m2 * f)), by = .(group = LANDIS)] }
m[, w_tpa := w * TPA_UNADJ]
ST_ <- alloc("w_tpa"); SB <- alloc("w")
cb <- fread(file.path(B, "cohort_biomass_by_mapcode.csv"))
SIC <- merge(px[, .(npix = sum(npix)), by = MapCode], cb[, .(g = sum(CohortBiomass)), by = .(MapCode, SpeciesName)], by = "MapCode", allow.cartesian = TRUE)[, .(v = sum(as.numeric(npix) * g)), by = .(group = SpeciesName)]
FI <- fread(file.path(SA, "out", sprintf("preanchor_shares_%s_s43.csv", ST)))[kind == "species_group", .(group, fia_share, track_a_ic_share = ic_share)]
sh <- function(x, nm) { x <- copy(x)[, (nm) := v / sum(v)][, v := NULL]; x }
R <- Reduce(function(a, b) merge(a, b, by = "group", all = TRUE), list(FI, sh(SF, "S_F_treemap_fiadb"), sh(ST_, "S_T_alloc_tpa"), sh(SB, "S_B_alloc_builder"), sh(SIC, "S_IC_builder_output")))
R[, state := ST]; fwrite(R, file.path(O, sprintf("aspen_diag_stages_%s_G.csv", ST)))
print(R[group %in% c("QA", "BA", "RP", "CE", "BS", "TAM", "BSW", "SM"), lapply(.SD, function(z) if (is.numeric(z)) round(z, 4) else z)])
# microplot (DIA < 5 in) part of QA biomass under FIADB weights vs builder weights
sap <- m[TM_ID %in% okp, .(F_lt5 = sum((npix * DRYBIO_AG * TPA_F)[DIA < 5]) / sum(npix * DRYBIO_AG * TPA_F)), by = .(group = LANDIS)]
tpa <- m[, .(tpa_mean_rec = mean(TPA_UNADJ), rec_lt5 = mean(DIA < 5)), by = .(group = LANDIS)]
fwrite(merge(sap, tpa, by = "group"), file.path(O, sprintf("aspen_diag_sapling_%s_G.csv", ST)))
print(merge(sap, tpa, by = "group")[group %in% c("QA", "BA", "CE", "BS", "TAM", "SM"), .(group, F_lt5 = round(F_lt5, 4), tpa_mean_rec = round(tpa_mean_rec, 2), rec_lt5 = round(rec_lt5, 3))])
# Lookup check: Populus and all unmapped SPCDs, share of S_F biomass
pv <- tt[TM_ID %in% okp, .(v = sum(npix * DRYBIO_AG * TPA_F, na.rm = TRUE)), by = .(SPCD, LANDIS)][, share_all := v / sum(v)][, v := NULL]
pop <- pv[SPCD %between% c(740, 753)][order(SPCD)]
fwrite(pv[order(-share_all)], file.path(O, sprintf("aspen_diag_spcd_%s_G.csv", ST)))
cat("Populus SPCDs (share of all live TreeMap-assigned FIADB AGB):\n"); print(pop[, .(SPCD, LANDIS, share = round(share_all, 4))])
cat("unmapped share", round(pv[is.na(LANDIS), sum(share_all)], 4), "\n")
cat("ASPEN_DIAG_DONE\n")
