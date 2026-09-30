#!/usr/bin/env Rscript
# stage4_species.R: species.txt, SpeciesData.csv and species_lookup_<ST>.R for NH VT MI WI from the
# ME (NE pool, 15 spp incl RO/HICK) and MN (Lake States pool, 24 spp) templates, via ONE shared crosswalk
# (species_crosswalk_NE_LS_20260929.csv). Reports every state species absent from the parameter set with
# its share of live basal area (never silently dropped).
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
SC <- file.path(FB, "scripts_20260929"); W <- file.path(FB, "work_20260929")
R  <- path.expand("~/restricted/ncasi-modeleval/fia_data_landis")
cw <- fread(file.path(SC, "species_crosswalk_NE_LS_20260929.csv"), colClasses = list(character = c("NE_CODE", "LS_CODE")))
cw[is.na(NE_CODE), NE_CODE := ""]; cw[is.na(LS_CODE), LS_CODE := ""]
nm <- unique(fread(file.path(FB, "TREEMAP/TM2022/TreeMap2022_CONUS_Tree_Table.csv"), select = c("SPCD", "COMMON_NAME", "SCIENTIFIC_NAME")), by = "SPCD")
POOL <- list(NH = "NE", VT = "NE", MI = "LS", WI = "LS")
TPL  <- list(NE = file.path(FB, "states/ME/inputs"), LS = file.path(FB, "states/MN/inputs"))
SPP_ECO <- list(NH = "SppEcoregionData_fia.csv", VT = "SppEcoregionData.csv", MI = "SppEcoregionData.csv", WI = "SppEcoregionData.csv")
S1CODES <- list(NH = c(58, 59), VT = c(58, 59, 83), MI = c(50, 51, 55, 56, 57), WI = c(47, 50, 51, 52, 53, 54))
unm_all <- list(); ba_all <- list()
for (ST in names(POOL)) {
  pool <- POOL[[ST]]; col <- paste0(pool, "_CODE"); IN <- file.path(FB, "states", ST, "inputs")
  # --- live BA composition, annual-design plots (latest INVYR >= 2010), each plot's latest visit
  t <- fread(file.path(R, paste0(ST, "_TREE.csv")), select = c("STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "STATUSCD", "SPCD", "DIA", "TPA_UNADJ"))
  t <- t[INVYR < 9999]; t[, pid := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
  last <- t[, .(INVYR = max(INVYR)), by = pid][INVYR >= 2010]
  t <- t[last, on = .(pid, INVYR)][STATUSCD == 1 & DIA >= 1 & !is.na(TPA_UNADJ)]
  b <- t[, .(ba = sum(TPA_UNADJ * 0.005454154 * DIA^2), ntree = .N), by = SPCD][, share := ba / sum(ba)]
  b <- merge(b, nm, by = "SPCD", all.x = TRUE)
  b <- merge(b, cw[, .(SPCD, CODE = get(col), SOURCE = get(sub("CODE", "SOURCE", col)))], by = "SPCD", all.x = TRUE)
  b[is.na(CODE), `:=`(CODE = "", SOURCE = "NOT_IN_CROSSWALK")]
  b[, state := ST]; b[, pool := pool]; setorder(b, -share)
  cat(sprintf("%s: %d annual plots (latest INVYR 2010+, range %s), %d live trees, %d SPCD\n", ST, nrow(last),
              paste(range(last$INVYR), collapse = "-"), nrow(t), nrow(b)))
  ba_all[[ST]] <- b
  # --- parameter set species (Dryad / FIA-calibrated SppEcoregionData for this state)
  se <- fread(file.path(IN, SPP_ECO[[ST]]))
  pset <- sort(unique(se$SpeciesCode))
  tsp <- readLines(file.path(TPL[[pool]], "species.txt"))
  tsp_codes <- sort(sapply(strsplit(grep("^[A-Z]", trimws(tsp), value = TRUE)[-1], "[ \t]+"), `[`, 1))
  sd <- fread(file.path(TPL[[pool]], "SpeciesData.csv"))
  gate(ST, "stage4", "species_txt_equals_param_set", setequal(tsp_codes, pset), paste(length(tsp_codes), "vs", length(pset)),
       "species.txt codes == SppEcoregionData species", paste0(pool, " template species.txt vs ", SPP_ECO[[ST]]))
  gate(ST, "stage4", "SpeciesData_equals_param_set", setequal(sd$SpeciesCode, pset), paste(nrow(sd), "vs", length(pset)),
       "SpeciesData codes == SppEcoregionData species", paste0(pool, " template SpeciesData.csv"))
  gate(ST, "stage4", "param_set_covers_stage1_ecoregions", all(S1CODES[[ST]] %in% unique(se$EcoregionName)),
       paste(sort(unique(se$EcoregionName)), collapse = " "), paste("contains", paste(S1CODES[[ST]], collapse = " ")),
       "every stage one L3 code needs SppEcoregionData rows")
  mapped <- b[CODE != ""]
  gate(ST, "stage4", "lookup_codes_in_param_set", all(mapped$CODE %in% pset), paste(setdiff(unique(mapped$CODE), pset), collapse = " "),
       "no lookup target outside parameter set", "crosswalk vs SppEcoregionData")
  msh <- sum(mapped$share)
  gate(ST, "stage4", "mapped_BA_share", msh >= 0.95, sprintf("%.4f", msh), ">= 0.95",
       "set here: at most 5% of live BA may fall outside the parameter set; unmapped species listed in unmapped_species_20260929.csv")
  tpl_share <- b[SOURCE %in% c("ME_template", "MN_template"), sum(share)]
  cat(sprintf("   BA share mapped by template rows %.4f, by ADDED_20260929 rows %.4f, unmapped %.4f\n",
              tpl_share, b[grepl("ADDED", SOURCE), sum(share)], 1 - msh))
  unm_all[[ST]] <- b[CODE == "", .(state, pool, SPCD, COMMON_NAME, SCIENTIFIC_NAME, ba_share = round(share, 5), ntree, SOURCE)]
  # --- write species_lookup_<ST>.R (drop-in: data.table SPECIES_LOOKUP with SPCD, LANDIS)
  lk <- cw[get(col) != "", .(SPCD, LANDIS = get(col), SOURCE = get(sub("CODE", "SOURCE", col)))]
  lk <- merge(lk, nm, by = "SPCD", all.x = TRUE); setorder(lk, SPCD)
  lp <- beside(file.path(IN, paste0("species_lookup_", ST, ".R")))
  con <- file(lp, "w")
  writeLines(c(sprintf("# species_lookup_%s.R  generated 2026-09-29 by scripts_20260929/stage4_species.R", ST),
               sprintf("# FIA SPCD -> LANDIS-II code, %s pool (%s template). Shared crosswalk: species_crosswalk_NE_LS_20260929.csv", pool, basename(TPL[[pool]] |> dirname())),
               "# Rows tagged ADDED_20260929_REVIEW are lumps added here and need Aaron's review.",
               "SPECIES_LOOKUP <- data.table::data.table(",
               sprintf("  SPCD = c(%s),", paste(lk$SPCD, collapse = ", ")),
               sprintf("  LANDIS = c(%s),", paste0('"', lk$LANDIS, '"', collapse = ", ")),
               sprintf("  SOURCE = c(%s)", paste0('"', lk$SOURCE, '"', collapse = ", ")),
               ")"), con)
  for (i in seq_len(nrow(lk))) writeLines(sprintf("#   %d %s  %s (%s)", lk$SPCD[i], lk$LANDIS[i], lk$COMMON_NAME[i], lk$SOURCE[i]), con)
  close(con)
  e <- new.env(); sys.source(lp, e)
  gate(ST, "stage4", "lookup_sources_cleanly", exists("SPECIES_LOOKUP", e) && nrow(e$SPECIES_LOOKUP) == nrow(lk), nrow(lk), "SPECIES_LOOKUP rows", "builder contract (SPCD, LANDIS)")
  # --- species.txt with provenance header, SpeciesData.csv copied unchanged
  spp <- beside(file.path(IN, "species.txt"))
  hdr <- c(sprintf(">> %s species.txt generated 2026-09-29 (scripts_20260929/stage4_species.R).", ST),
           sprintf(">> Copied from the %s template (%s/species.txt); species set equals %s.", pool, sub(path.expand("~"), "~", TPL[[pool]]), SPP_ECO[[ST]]))
  out <- append(tsp, hdr, after = 1)
  writeLines(out, spp)
  sdp <- beside(file.path(IN, "SpeciesData.csv"))
  file.copy(file.path(TPL[[pool]], "SpeciesData.csv"), sdp, overwrite = FALSE)
  cat("   wrote", lp, spp, sdp, "\n")
}
unm <- rbindlist(unm_all); fwrite(unm, file.path(W, "unmapped_species_20260929.csv"))
for (ST in names(POOL)) file.copy(file.path(W, "unmapped_species_20260929.csv"), beside(file.path(FB, "states", ST, "inputs", "unmapped_species_20260929.csv")))
ba <- rbindlist(ba_all, fill = TRUE); fwrite(ba[, .(state, pool, SPCD, COMMON_NAME, share = round(share, 5), ntree, CODE, SOURCE)], file.path(W, "state_ba_mapping_20260929.csv"))
cat("\nUNMAPPED (share >= 0.001):\n"); print(unm[ba_share >= 0.001], nrows = 200)
