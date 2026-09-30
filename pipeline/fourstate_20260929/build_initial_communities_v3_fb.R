#!/usr/bin/env Rscript
#
# build_initial_communities_v2.R
#
# Properly state-aware LANDIS-II Initial Communities builder. Reads CLI args
# instead of hardcoded Maine paths.
#
# Required args:
#   --state    STATE     two-letter state code (ME, MN, GA, WA)
#   --treemap  PATH      state-clipped TreeMAP raster (30 m)
#   --tree     PATH      state-subset FIA Tree CSV (PLT_CN, SPCD, DIA, HT, STATUSCD)
#   --cond     PATH      state FIA condition CSV (PLT_CN, CONDID, STDAGE, FORTYPCD)
#   --eco      PATH      state EPA L3 ecoregion raster
#   --lookup   PATH      R file defining SPECIES_LOOKUP data.table (SPCD, LANDIS)
#   --out      PATH      output directory (initial_communities/ subdir created)
#
# Optional:
#   --tile     "xmin,ymin,xmax,ymax"   crop bbox for testing
#   --tm-dbf   PATH      override default TreeMAP DBF (defaults to CONUS table)
#   --tm-tree  PATH      override default TreeMAP CONUS Tree Table (used for fallback)
#
# Usage:
#   Rscript build_initial_communities_v2.R \
#     --state MN \
#     --treemap /fs/scratch/.../states/MN/inputs/MN_TM_22.tif \
#     --tree    /fs/scratch/.../states/MN/inputs/MN_TREE.csv \
#     --cond    /fs/scratch/.../states/MN/inputs/MN_COND.csv \
#     --eco     /fs/scratch/.../states/MN/inputs/MN_ecoregion_l3.tif \
#     --lookup  /fs/scratch/.../states/MN/inputs/species_lookup.R \
#     --out     /fs/scratch/.../states/MN/inputs

# ---- firebreather adaptation (scripts_20260929) ----------------------------
# 1. optparse is not installed on firebreather: base-R parser for the same flags.
# 2. TreeMap 2022 DBF and tree table defaults point at ~/landis2_fb/TREEMAP/TM2022.
# 3. The copy of outputs up one level never overwrites (dated variant instead).
# 4. Logs STDAGE NA count (template behaviour pmax(NA,1,na.rm=TRUE)=1 kept) and COND match rate.
# Everything else is the Cardinal v3 builder unchanged.
suppressPackageStartupMessages({
  library(terra)
  library(data.table)
  library(foreign)
})
parse_flags <- function(a) {
  o <- list(); i <- 1
  while (i <= length(a)) {
    k <- sub("^--", "", a[i]); if (i == length(a)) stop("flag without value: ", a[i])
    o[[k]] <- a[i + 1]; i <- i + 2
  }
  o
}
opt <- parse_flags(commandArgs(trailingOnly = TRUE))
TM22 <- path.expand("~/landis2_fb/TREEMAP/TM2022")
if (is.null(opt$tile)) opt$tile <- NA
if (is.null(opt$`tm-dbf`)) opt$`tm-dbf` <- file.path(TM22, "TreeMap2022_CONUS.tif.vat.dbf")
if (is.null(opt$`tm-tree-fallback`)) opt$`tm-tree-fallback` <- file.path(TM22, "TreeMap2022_CONUS_Tree_Table.csv")
beside <- function(path, tag = "20260929") {
  if (!file.exists(path)) return(path)
  ext <- tools::file_ext(path); stem <- sub(paste0("[.]", ext, "$"), "", path)
  p2 <- paste0(stem, "_", tag, ".", ext)
  if (file.exists(p2)) stop("dated variant already exists: ", p2)
  message("NOTE target exists, writing dated variant: ", p2); p2
}

required <- c("state", "treemap", "tree", "cond", "lookup", "out")
miss <- required[sapply(required, function(x) is.null(opt[[x]]))]
if (length(miss) > 0) stop("Missing required args: ", paste(miss, collapse = ", "))

ST       <- opt$state
TM_RAS   <- opt$treemap
TREE_CSV <- opt$tree
COND_CSV <- opt$cond
LOOKUP_R <- opt$lookup
OUT_DIR  <- file.path(opt$out, "initial_communities")
TM_DBF   <- opt$`tm-dbf`
TM_TREE_FALLBACK <- opt$`tm-tree-fallback`

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

log <- function(...) cat(format(Sys.time(), "[%H:%M:%S]"), ..., "\n")

log(sprintf("====== %s IC builder v2 ======", ST))
log("  treemap: ", TM_RAS)
log("  tree:    ", TREE_CSV)
log("  cond:    ", COND_CSV)
log("  lookup:  ", LOOKUP_R)
log("  out:     ", OUT_DIR)

##############################################################################
# Source state-specific species lookup
##############################################################################
log(sprintf("Sourcing %s species lookup", ST))
source(LOOKUP_R)
if (!exists("SPECIES_LOOKUP")) {
  stop("Sourced lookup file did not define SPECIES_LOOKUP. ",
       "Expected a data.table with columns SPCD and LANDIS.")
}
SPECIES_LOOKUP <- as.data.table(SPECIES_LOOKUP)
if (!all(c("SPCD", "LANDIS") %in% names(SPECIES_LOOKUP))) {
  stop("SPECIES_LOOKUP must have columns SPCD and LANDIS")
}
SPECIES_LOOKUP <- unique(SPECIES_LOOKUP, by = "SPCD")
log(sprintf("  %d species mappings loaded", nrow(SPECIES_LOOKUP)))

##############################################################################
# Cohort age binning constants
##############################################################################
AGE_BIN_WIDTH <- 5
DBH_LARGE_CM  <- 25
DBH_MEDIUM_CM <- 12

bin_age <- function(a) {
  a <- pmax(a, 1)
  pmax(round(a / AGE_BIN_WIDTH) * AGE_BIN_WIDTH, AGE_BIN_WIDTH)
}

##############################################################################
# Step 1. Read state TreeMAP raster
##############################################################################
log(sprintf("1. Reading %s TreeMAP raster", ST))
r_tm <- rast(TM_RAS)
log("   resolution:", paste(res(r_tm), collapse = " x "), "m")
log("   ncell:", ncell(r_tm), " size:", paste(dim(r_tm)[1:2], collapse = " x "))
log("   crs:", crs(r_tm, describe = TRUE)$code)

if (!is.na(opt$tile)) {
  e <- as.numeric(strsplit(opt$tile, ",")[[1]])
  log("   cropping to tile:", opt$tile)
  r_tm <- crop(r_tm, ext(e))
}

log("   extracting unique TM_IDs (this scans the raster) ...")
tm_ids <- unique(values(r_tm, na.rm = TRUE))
tm_ids <- tm_ids[tm_ids > 0]
log(sprintf("   n unique TM_IDs in %s: %d", ST, length(tm_ids)))
if (length(tm_ids) == 0) stop("No TM_IDs found in raster — check --treemap")

##############################################################################
# Step 2. TreeMAP DBF (TM_ID -> PLT_CN linker)
##############################################################################
log("2. Reading TreeMAP DBF (TM_ID -> PLT_CN linker)")
dbf <- as.data.table(vect(TM_DBF))
keep <- intersect(c("TM_ID", "PLT_CN", "FORTYPCD", "BALIVE", "STANDHT",
                    "QMD", "TPA_LIVE", "DRYBIO_L", "CARBON_L"), names(dbf))
dbf_st <- dbf[TM_ID %in% tm_ids, ..keep]
log(sprintf("   %s DBF subset rows: %d  cols: %s",
            ST, nrow(dbf_st), paste(keep, collapse = ", ")))

##############################################################################
# Step 3. Tree records
##############################################################################
log("3. Reading state FIA Tree records")
# Try state subset first (faster); fall back to CONUS table filtered by TM_ID
if (file.exists(TREE_CSV) && file.size(TREE_CSV) > 1000) {
  tree <- fread(TREE_CSV)
  log(sprintf("   read state Tree CSV: %d rows", nrow(tree)))
} else {
  log(sprintf("   state Tree CSV missing/empty, falling back to CONUS table"))
  tree <- fread(TM_TREE_FALLBACK,
                select = c("TM_ID", "PLT_CN", "STATUSCD", "SPCD", "DIA", "HT"))
}

# Normalize column names: state Tree CSVs may have additional FIA cols
need_cols <- c("TM_ID", "PLT_CN", "STATUSCD", "SPCD", "DIA", "HT")
miss_cols <- setdiff(need_cols, names(tree))
if (length(miss_cols) > 0) {
  log(sprintf("   missing cols in tree input: %s", paste(miss_cols, collapse = ", ")))
  if ("STATUSCD" %in% miss_cols) {
    log("   adding STATUSCD = 1 (assume all live)")
    tree[, STATUSCD := 1L]
  }
  miss_cols <- setdiff(need_cols, names(tree))
  if (length(miss_cols) > 0) stop("Cannot continue without: ",
                                  paste(miss_cols, collapse = ", "))
}

tree_st <- tree[TM_ID %in% tm_ids & STATUSCD == 1]
log(sprintf("   %s live tree rows: %d", ST, nrow(tree_st)))
rm(tree); gc()

# Map FIA species code -> LANDIS species code via state-specific lookup
tree_st <- merge(tree_st, SPECIES_LOOKUP[, .(SPCD, LANDIS)], by = "SPCD", all.x = TRUE)
unmapped <- tree_st[is.na(LANDIS), .N, by = SPCD][order(-N)]
if (nrow(unmapped) > 0) {
  log(sprintf("   WARNING: %d unmapped SPCDs (will be dropped). Top 10:",
              nrow(unmapped)))
  print(head(unmapped, 10))
}
tree_st <- tree_st[!is.na(LANDIS)]
log(sprintf("   tree rows after species filter: %d", nrow(tree_st)))
if (nrow(tree_st) == 0) stop("No mapped species in tree records — check lookup vs SPCDs")

##############################################################################
# Step 4. Stand age from FIA condition table
##############################################################################
log("4. Reading FIA condition table for STDAGE")
cond <- fread(COND_CSV)
need_cond <- c("PLT_CN", "CONDID", "STDAGE")
miss_cond <- setdiff(need_cond, names(cond))
if (length(miss_cond) > 0) stop("COND missing cols: ", paste(miss_cond, collapse = ", "))
log(sprintf("   CONDID 1 rows with STDAGE NA (coerced to 1 by template pmax): %d of %d",
            cond[CONDID == 1, sum(is.na(STDAGE))], cond[CONDID == 1, .N]))
cond1 <- cond[CONDID == 1, .(PLT_CN, STDAGE = pmax(STDAGE, 1L, na.rm = TRUE))]
cond1[, STDAGE := as.integer(STDAGE)]
log("   condition rows:", nrow(cond1))

median_age <- as.integer(median(cond1$STDAGE, na.rm = TRUE))
log("   median STDAGE for backstop:", median_age, "yr")

tree_st[, PLT_CN := as.character(PLT_CN)]
cond1[,   PLT_CN := as.character(PLT_CN)]
tree_st <- merge(tree_st, cond1[, .(PLT_CN, STDAGE)], by = "PLT_CN", all.x = TRUE)
log(sprintf("   live tree rows with no COND match (median age backstop): %d of %d; plots unmatched %d of %d",
            tree_st[is.na(STDAGE), .N], nrow(tree_st), tree_st[is.na(STDAGE), uniqueN(PLT_CN)], uniqueN(tree_st$PLT_CN)))
tree_st[is.na(STDAGE), STDAGE := median_age]

##############################################################################
# Step 5. Bin trees into cohorts
##############################################################################
log("5. Binning trees into cohorts")
tree_st[, DIA_CM := DIA * 2.54]
tree_st[, dbh_class := fifelse(DIA_CM >= DBH_LARGE_CM, "L",
                       fifelse(DIA_CM >= DBH_MEDIUM_CM, "M", "S"))]
tree_st[, cohort_age := bin_age(fcase(
  dbh_class == "L", STDAGE,
  dbh_class == "M", STDAGE - 20L,
  dbh_class == "S", STDAGE - 40L
))]

cohorts <- unique(tree_st[, .(TM_ID, LANDIS, cohort_age)])
log("   unique (TM_ID, species, age) cohorts:", nrow(cohorts))

##############################################################################
# Step 6. Generate MapCodes
##############################################################################
log("6. Assigning MapCodes")
cohorts <- cohorts[order(TM_ID, LANDIS, cohort_age)]
sig <- cohorts[, .(signature = paste(LANDIS, cohort_age, collapse = "|")), by = TM_ID]
unique_sigs <- unique(sig$signature)
sig_lookup  <- data.table(signature = unique_sigs, MapCode = seq_along(unique_sigs))
sig <- merge(sig, sig_lookup, by = "signature")
cohorts <- merge(cohorts, sig[, .(TM_ID, MapCode)], by = "TM_ID")
log("   unique MapCodes:", nrow(sig_lookup))

## Step 6b. FIA-anchored per-cohort biomass (apportion plot DRYBIO_L by tree DIA^2.5 share)
log("6b. Apportioning FIA DRYBIO_L to cohorts (year-0 biomass anchor)")
if ("DRYBIO_L" %in% names(dbf_st)) {
  ts <- tree_st[, .(TM_ID, LANDIS, cohort_age, DIA_CM)]
  ts[, w := pmax(DIA_CM, 0.1)^2.5]
  biop <- dbf_st[, .(TM_ID, DRYBIO_L)]
  biop[, g_m2 := DRYBIO_L * 1000 * 0.4536 / 0.4047 / 10]
  biop <- biop[is.finite(g_m2) & g_m2 > 0]
  ts <- merge(ts, biop, by = "TM_ID")
  Wp <- ts[, .(Wp = sum(w)), by = TM_ID]
  cb <- ts[, .(wc = sum(w), g_m2 = g_m2[1]), by = .(TM_ID, LANDIS, cohort_age)]
  cb <- merge(cb, Wp, by = "TM_ID")
  cb[, biomass_g_m2 := g_m2 * wc / Wp]
  cb <- merge(cb, sig[, .(TM_ID, MapCode)], by = "TM_ID")
  cbm <- cb[, .(CohortBiomass = round(mean(biomass_g_m2))), by = .(MapCode, LANDIS, cohort_age)]
  setnames(cbm, c("LANDIS", "cohort_age"), c("SpeciesName", "CohortAge"))
  cbm <- cbm[is.finite(CohortBiomass) & CohortBiomass > 0]
  fwrite(cbm, file.path(OUT_DIR, "cohort_biomass_by_mapcode.csv"))
  log(sprintf("   cohort_biomass rows %d mean %.0f g/m2 range %.0f-%.0f",
              nrow(cbm), mean(cbm[["CohortBiomass"]]), min(cbm[["CohortBiomass"]]), max(cbm[["CohortBiomass"]])))
}

##############################################################################
# Step 7. Write LANDIS-II IC text
##############################################################################
log("7. Writing initial_communities.txt")
ic_path <- file.path(OUT_DIR, "initial_communities.txt")
con <- file(ic_path, "w")
writeLines("LandisData    \"Initial Communities\"", con)
writeLines("", con)
mapcodes <- sort(unique(cohorts$MapCode))
for (mc in mapcodes) {
  writeLines(sprintf("MapCode %d", mc), con)
  sub <- cohorts[MapCode == mc]
  for (sp in sort(unique(sub$LANDIS))) {
    ages <- sort(unique(sub[LANDIS == sp, cohort_age]))
    writeLines(sprintf("\t%s %s", sp, paste(ages, collapse = " ")), con)
  }
}
close(con)
log(sprintf("   wrote: %s  (%d communities)", ic_path, nrow(sig_lookup)))

##############################################################################
# Step 8. Write IC raster
##############################################################################
log("8. Writing initial-communities.tif")
tm_to_mc <- merge(sig[, .(TM_ID, MapCode)],
                   data.table(TM_ID = tm_ids), by = "TM_ID", all.y = TRUE)
tm_to_mc[is.na(MapCode), MapCode := 0L]
tm_to_mc <- tm_to_mc[order(TM_ID)]

rcl <- as.matrix(tm_to_mc[, .(TM_ID, MapCode)])
ic_ras_path <- file.path(OUT_DIR, "initial-communities.tif")
r_ic <- classify(r_tm, rcl, others = 0)
writeRaster(r_ic, ic_ras_path,
            datatype = "INT4U", overwrite = TRUE,
            gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES"))
log("   wrote:", ic_ras_path)

##############################################################################
# Step 9. Also write a copy of the IC raster up one level (where downstream
# scripts expect it) and provenance files
##############################################################################
up_tif <- beside(file.path(opt$out, "initial-communities.tif"))
up_txt <- beside(file.path(opt$out, "initial_communities.txt"))
file.copy(ic_ras_path, up_tif, overwrite = FALSE)
file.copy(ic_path,     up_txt, overwrite = FALSE)
log("   installed:", up_tif, up_txt)
fwrite(tm_to_mc,        file.path(OUT_DIR, "tm_to_mapcode.csv"))
fwrite(SPECIES_LOOKUP,  file.path(OUT_DIR, "species_lookup.csv"))

##############################################################################
# Step 10. Validation summary + AGB cross check
##############################################################################
log("9. Summary")
log("   IC raster:", file.path(opt$out, "initial-communities.tif"))
log("   IC text:  ", file.path(opt$out, "initial_communities.txt"))
log("   unique MapCodes:", nrow(sig_lookup))
log(sprintf("   total %s pixels with cohorts: %d", ST, sum(tm_to_mc$MapCode > 0)))
log("   total live tree records used:", nrow(tree_st))


## Step 9b. Year-0 anchored biomass total from MapCode-mean cohort biomass
if (file.exists(file.path(OUT_DIR, "cohort_biomass_by_mapcode.csv"))) {
  cbm2 <- fread(file.path(OUT_DIR, "cohort_biomass_by_mapcode.csv"))
  mcb  <- cbm2[, .(bio_g_m2 = sum(CohortBiomass)), by = MapCode]
  m2_pix <- prod(res(r_tm))
  v <- merge(tm_to_mc[MapCode > 0, .N, by = MapCode], mcb, by = "MapCode", all.x = TRUE)
  v[is.na(bio_g_m2), bio_g_m2 := 0]
  yr0_tg <- v[, sum(N * bio_g_m2 * m2_pix) / 1e12]
  log(sprintf("   YEAR-0 anchored biomass total (MapCode-mean apportioned): %.1f Tg", yr0_tg))
}
# State FIA AGB targets for cross check
FIA_TARGET <- c(ME = 677, MN = 1000, GA = 2800, WA = 3000)
target_tg <- FIA_TARGET[ST]

if ("DRYBIO_L" %in% names(dbf_st)) {
  dbf_st[, drybio_kgha := DRYBIO_L * 1000 * 0.4536 / 0.4047]
  pixel_ha <- prod(res(r_tm)) / 1e4
  agb_total_tg <- tm_to_mc[MapCode > 0,
    .N, by = TM_ID][dbf_st, on = "TM_ID", nomatch = 0
    ][, sum(N * pixel_ha * drybio_kgha) / 1e9]
  if (!is.na(target_tg)) {
    pct <- 100 * (agb_total_tg - target_tg) / target_tg
    log(sprintf("   AGB total: %.1f Tg vs %s FIA target ~%d Tg (%+.1f%%)",
                agb_total_tg, ST, target_tg, pct))
  } else {
    log(sprintf("   AGB total: %.1f Tg (no FIA target on file for %s)",
                agb_total_tg, ST))
  }
}

log(sprintf("DONE — %s IC ready for Phase 2", ST))
