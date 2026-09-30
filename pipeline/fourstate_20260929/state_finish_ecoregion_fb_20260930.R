#!/usr/bin/env Rscript
## ---------------------------------------------------------------------------
## state_finish_ecoregion
##
## NCASI Model Evaluation Phase II, session 26, item five, part one.
## Builds on tools/state_finish.R, which is not modified.
##
## state_finish.R derives BiomassMax as a STATEWIDE 99th percentile of per-plot
## per-species aboveground biomass, then writes the same value into every
## ecoregion row for that species.  A state with seven ecoregions therefore
## carries one number per species repeated seven times, which is the thing the
## published methods text does not say and which this script replaces.
##
## Here the quantile is taken within (species, ecoregion), with FIA plots
## assigned to ecoregions by extracting the state's LANDIS ecoregion raster at
## the plot coordinate.  A (species, ecoregion) cell with fewer than MIN_PLOTS
## plots falls back to that species' statewide quantile, and every fallback is
## counted and reported rather than absorbed.
##
## This script does NOT redo the initial-communities anchoring in state_finish.R.
## That step already ran for the states this can run on and its output is left
## alone.
##
## RESTRICTED DATA. This reads FIA plot LAT and LON to assign an ecoregion and
## leaves them behind.  No coordinate and no PLT_CN appears in any output, and
## the script asserts that before it writes.  It runs on firebreather under ~/restricted (routing changed 28 Sep 2026); this copy is patched for firebreather paths, session 32.
##
## Usage: Rscript state_finish_ecoregion_2026-09-23.R <ST>
## ---------------------------------------------------------------------------

suppressPackageStartupMessages({library(terra); library(data.table)})
args <- commandArgs(TRUE)
ST <- args[1]
if (is.na(ST) || ST == "") stop("usage: state_finish_ecoregion_2026-09-23.R <ST>")

L <- path.expand("~/landis2_fb")
F <- path.expand("~/restricted/ncasi-modeleval/fia_data_landis/stage7_20260930")
IN <- file.path(L, "states", ST, "inputs")
MIN_PLOTS <- 20L
STAMP <- format(Sys.Date(), "%Y%m%d")

say <- function(...) cat(sprintf("[%s] ", ST), sprintf(...), "\n", sep = "")
numify <- function(dt, cols) for (c in cols) if (c %in% names(dt)) set(dt, j = c, value = as.numeric(dt[[c]]))

## --- prerequisites, named rather than assumed --------------------------------
need <- c(spp = file.path(IN, "SppEcoregionData.csv"),
          lut = file.path(IN, sprintf("species_lookup_%s.R", ST)),
          eco = file.path(IN, "ecoregions_20260929.tif"),
          tre = file.path(path.expand("~/restricted/ncasi-modeleval/fia_data_landis"), paste0(ST, "_TREE.csv")),
          plt = file.path(F, paste0(ST, "_PLOT.csv")),
          psa = file.path(F, paste0(ST, "_POP_PLOT_STRATUM_ASSGN.csv")))
missing <- need[!file.exists(need)]
if (length(missing))
  stop(sprintf("%s cannot run; missing: %s", ST,
               paste(sprintf("%s (%s)", names(missing), missing), collapse = "; ")))

## --- EVALID, exactly as state_finish.R picks it ------------------------------
psa <- fread(need[["psa"]], colClasses = list(character = c("PLT_CN", "STRATUM_CN")))
strat_ev <- unique(as.integer(fread(file.path(F, "ENTIRE_POP_STRATUM.csv"),
                                    colClasses = list(character = "CN"))$EVALID))
cand <- psa[as.integer(EVALID) %in% strat_ev, .N, by = EVALID][order(-N)]
EVID <- as.integer(cand[1]$EVALID)
say("EVALID %d", EVID)
psa <- unique(psa[as.integer(EVALID) == EVID, .(PLT_CN)])
stopifnot("no plots on the chosen EVALID" = nrow(psa) > 100)

## --- plot to ecoregion, by raster extraction ---------------------------------
pl <- fread(need[["plt"]], colClasses = list(character = "CN"), select = c("CN", "LAT", "LON"))
setnames(pl, "CN", "PLT_CN")
numify(pl, c("LAT", "LON"))
pl <- pl[is.finite(LAT) & is.finite(LON)]
pl <- pl[psa, on = "PLT_CN", nomatch = 0]
say("plots on EVALID with usable coordinates: %s", format(nrow(pl), big.mark = ","))
stopifnot("too few located plots" = nrow(pl) > 100)

r <- rast(need[["eco"]])
pts <- vect(as.data.frame(pl[, .(LON, LAT)]), geom = c("LON", "LAT"), crs = "EPSG:4269")
pts <- project(pts, crs(r))
ex <- terra::extract(r, pts)
pl[, eco := as.integer(ex[[2]])]
rm(pts, ex)
n_off <- pl[is.na(eco) | eco == 0, .N]
pl <- pl[!is.na(eco) & eco != 0]
say("assigned to an active ecoregion: %s plots; %s fell on nodata or outside the raster",
    format(nrow(pl), big.mark = ","), format(n_off, big.mark = ","))
stopifnot("ecoregion assignment lost nearly everything" = nrow(pl) > 100)
plot_eco <- pl[, .(PLT_CN, eco)]
rm(pl); gc()   ## coordinates dropped here and never re-read

## --- per plot per species biomass, as state_finish.R computes it -------------
tr <- fread(need[["tre"]], colClasses = list(character = "PLT_CN"),
            select = c("PLT_CN", "STATUSCD", "SPCD", "DRYBIO_AG", "TPA_UNADJ"))
numify(tr, c("STATUSCD", "SPCD", "DRYBIO_AG", "TPA_UNADJ"))
trl <- tr[STATUSCD == 1 & is.finite(DRYBIO_AG) & is.finite(TPA_UNADJ)]
rm(tr); gc()
source(need[["lut"]])
lut <- as.data.table(SPECIES_LOOKUP)[, .(SPCD = as.integer(SPCD), LANDIS)]
trl2 <- merge(trl[psa, on = "PLT_CN", nomatch = 0], lut, by = "SPCD")
trl2[, gm2 := DRYBIO_AG * TPA_UNADJ * 0.112085]
plotsp <- trl2[, .(gm2 = sum(gm2)), by = .(PLT_CN, LANDIS)]
plotsp <- merge(plotsp, plot_eco, by = "PLT_CN")
say("per plot per species records with an ecoregion: %s over %d species and %d ecoregions",
    format(nrow(plotsp), big.mark = ","), uniqueN(plotsp$LANDIS), uniqueN(plotsp$eco))

## --- the two quantiles --------------------------------------------------------
bmax_state <- plotsp[, .(bmax_state = round(quantile(gm2, 0.99, na.rm = TRUE)),
                         n_state = .N), by = LANDIS]
bmax_eco <- plotsp[, .(bmax_eco = round(quantile(gm2, 0.99, na.rm = TRUE)),
                       n_eco = .N), by = .(LANDIS, eco)]

spp <- fread(need[["spp"]])
n_in <- nrow(spp)
spp[, EcoregionName := as.character(EcoregionName)]
eco_in_spp <- sort(unique(spp$EcoregionName))
eco_in_ras <- sort(unique(as.character(bmax_eco$eco)))
say("ecoregions in SppEcoregionData: %s", paste(eco_in_spp, collapse = ", "))
say("ecoregions carrying plots:      %s", paste(eco_in_ras, collapse = ", "))
unserved <- setdiff(eco_in_spp, eco_in_ras)
if (length(unserved))
  say("NOTE: %d ecoregion(s) have no plots and will take the statewide value: %s",
      length(unserved), paste(unserved, collapse = ", "))

spp <- merge(spp, bmax_eco[, .(SpeciesCode = LANDIS, EcoregionName = as.character(eco),
                               bmax_eco, n_eco)],
             by = c("SpeciesCode", "EcoregionName"), all.x = TRUE)
spp <- merge(spp, bmax_state[, .(SpeciesCode = LANDIS, bmax_state, n_state)],
             by = "SpeciesCode", all.x = TRUE)
stopifnot("row count changed on the merges" = nrow(spp) == n_in)

fb_med <- as.numeric(median(bmax_state$bmax_state, na.rm = TRUE))
spp[, source := fifelse(!is.na(bmax_eco) & n_eco >= MIN_PLOTS, "ecoregion",
                 fifelse(!is.na(bmax_state), "statewide", "median"))]
spp[, BiomassMax_new := fifelse(source == "ecoregion", as.numeric(bmax_eco),
                         fifelse(source == "statewide", as.numeric(bmax_state), fb_med))]
spp[!is.finite(BiomassMax_new) | BiomassMax_new <= 0,
    `:=`(BiomassMax_new = pmin(as.numeric(BiomassMax), fb_med), source = "median")]

say("provenance of the %d rows: %s", nrow(spp),
    paste(sprintf("%s %d", names(table(spp$source)), as.integer(table(spp$source))), collapse = ", "))

## ANPPmax is scaled the same way state_finish.R scales it, never upward
spp[, factor := BiomassMax_new / BiomassMax]
spp[, ANPPmax := round(ANPPmax * pmin(factor, 1))]
spp[, BiomassMax_prev := BiomassMax]
spp[, BiomassMax := as.integer(round(BiomassMax_new))]
spp[, ProbMortality := 0.002]

## --- what actually moved ------------------------------------------------------
say("BiomassMax %d to %d g m-2, mean %.0f (was %d to %d, mean %.0f)",
    min(spp$BiomassMax), max(spp$BiomassMax), mean(spp$BiomassMax),
    min(spp$BiomassMax_prev), max(spp$BiomassMax_prev), mean(spp$BiomassMax_prev))
spread <- spp[, .(n_eco_rows = .N, lo = min(BiomassMax), hi = max(BiomassMax),
                  spread_pct = round(100 * (max(BiomassMax) - min(BiomassMax)) /
                                       pmax(1, min(BiomassMax)), 1)), by = SpeciesCode]
cat("\n-- within-species spread across ecoregions, which was zero by construction before --\n")
print(spread[order(-spread_pct)])

out_cols <- c("Year", "EcoregionName", "SpeciesCode", "ProbEstablish",
              "ProbMortality", "ANPPmax", "BiomassMax")
keep <- spp[, ..out_cols]
setcolorder(keep, out_cols)
setorder(keep, EcoregionName, SpeciesCode)

## restricted-data gate before anything is written
stopifnot("a coordinate or plot id column reached the output" =
            !any(grepl("LAT|LON|PLT_CN|CN$", names(keep))))
stopifnot("BiomassMax is not positive everywhere" = all(keep$BiomassMax > 0))
stopifnot("row count changed" = nrow(keep) == n_in)

target <- file.path(IN, "SppEcoregionData_fia_20260929.csv")
if (file.exists(target)) {
  bk <- file.path(IN, sprintf("SppEcoregionData_fia_PREV_%s.csv", STAMP))
  i <- 0L
  while (file.exists(bk)) {
    i <- i + 1L
    bk <- file.path(IN, sprintf("SppEcoregionData_fia_PREV_%s%s.csv", STAMP, letters[i]))
  }
  file.copy(target, bk)
  say("backed up existing file to %s", basename(bk))
} else {
  say("no existing SppEcoregionData_fia.csv; this state had none")
}
fwrite(keep, target)

## verify the delivered file rather than the object
back <- fread(target, colClasses = list(character = "EcoregionName"))
stopifnot("delivered row count wrong" = nrow(back) == n_in)
stopifnot("delivered columns wrong" = identical(names(back), out_cols))
stopifnot("delivered BiomassMax not positive" = all(back$BiomassMax > 0))
stopifnot("delivered file lost the ecoregion variation" =
            back[, uniqueN(BiomassMax), by = SpeciesCode][, max(V1)] > 1L)
say("wrote and re-read %s: %d rows, %d species, %d ecoregions",
    basename(target), nrow(back), uniqueN(back$SpeciesCode), uniqueN(back$EcoregionName))
say("DONE. Tier 2 reads the Dryad SppEcoregionData.csv, not this file: run_param_set_t2.sh line 41 sets SPP_BASE=$INPUTS/SppEcoregionData.csv. No theta refit is owed. Measured session 27, 2026-09-23.")
