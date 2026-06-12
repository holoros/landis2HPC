#!/usr/bin/env Rscript
# compose_sppeco_baseline.R
#
# Generalizes the WI/MI baseline repair across CONUS. For a state whose plots
# fall in ecoregions its SppEcoregionData baseline does not cover, this fills the
# missing ecoregions by copying the rows of a donor ecoregion that is already in
# the same baseline (same species universe), relabeled to the missing code. It
# never invents parameter values and never crosses species floras: the donor
# must already exist in that state's own baseline.
#
# This is the documented borrowed-parameter step, made explicit and logged. The
# default donor is the nearest covered ecoregion by numeric code; override per
# ecoregion with --map for an ecologically chosen analog (recommended).
#
# Usage:
#   Rscript compose_sppeco_baseline.R --state OH \
#       [--root DIR] [--ecos 83,...] [--map "83=61"] [--apply]
#
#   --ecos  ecoregions to ensure are present. Default: every model ecoregion the
#           state's plots map to (read from plot_to_ecoregion + build remaps).
#   --map   explicit donor per missing eco, e.g. "83=61,68=66". Unmapped missing
#           ecoregions fall back to nearest covered code.
#   --apply write the augmented baseline (after backing up). Without it, dry-run.
#
# Output: states/<ST>/inputs/SppEcoregionData.csv (backed up first) and a
# provenance CSV states/<ST>/inputs/SppEcoregionData_provenance.csv recording
# native vs composed rows and the donor used.

suppressMessages({ library(dplyr); library(readr); library(stringr); library(tidyr) })

args <- commandArgs(trailingOnly = TRUE)
opt <- function(flag, default = NA) { i <- which(args == flag); if (length(i) && i < length(args)) args[i + 1] else default }
has <- function(flag) flag %in% args

ROOT  <- opt("--root", "/fs/scratch/PUOM0008/crsfaaron/landis2")
ST    <- opt("--state", NA)
if (is.na(ST)) stop("--state is required")
APPLY <- has("--apply")
TOOLS <- file.path(ROOT, "tools"); STDIR <- file.path(ROOT, "states")
BASE  <- file.path(STDIR, ST, "inputs", "SppEcoregionData.csv")
if (!file.exists(BASE)) stop(sprintf("no baseline at %s; nothing to extend from (need a home baseline)", BASE))

## donor map override --------------------------------------------------------
map_arg <- opt("--map", NA)
donor_override <- list()
if (!is.na(map_arg)) for (kv in str_split(map_arg, ",")[[1]]) {
  p <- str_split(str_trim(kv), "=")[[1]]; donor_override[[p[1]]] <- as.integer(p[2])
}

## needed ecoregions ---------------------------------------------------------
needed <- if (!is.na(opt("--ecos", NA))) {
  as.integer(str_split(opt("--ecos"), ",")[[1]])
} else {
  pe <- file.path(TOOLS, sprintf("plot_to_ecoregion_%s.csv", ST))
  if (!file.exists(pe)) stop("no --ecos given and no plot_to_ecoregion file to infer from")
  d <- suppressWarnings(read_csv(pe, show_col_types = FALSE, progress = FALSE))
  raw <- sort(unique(as.integer(d[[3]]))); raw <- raw[!is.na(raw) & raw > 0]
  # apply build remaps if a build script exists
  bf <- file.path(TOOLS, sprintf("build_plot_scenario_%s.sh", ST))
  if (file.exists(bf)) {
    ln <- readLines(bf, warn = FALSE); m <- str_match(ln, "^\\s*([0-9]+)\\)\\s*ECO=([0-9]+)\\s*;")
    m <- m[!is.na(m[, 1]), , drop = FALSE]
    if (nrow(m)) { mm <- setNames(as.integer(m[, 3]), m[, 2]); raw <- ifelse(as.character(raw) %in% names(mm), mm[as.character(raw)], raw) }
  }
  sort(unique(raw))
}

## current baseline ----------------------------------------------------------
spp <- read_csv(BASE, show_col_types = FALSE, progress = FALSE)
eco_col <- names(spp)[2]
covered <- sort(unique(as.integer(spp[[eco_col]])))
missing <- setdiff(needed, covered)

cat(sprintf("\nstate %s\n covered ecoregions: %s\n needed:            %s\n missing:           %s\n",
            ST, paste(covered, collapse = " "), paste(needed, collapse = " "),
            if (length(missing)) paste(missing, collapse = " ") else "(none)"))

if (!length(missing)) { cat(" baseline already covers all needed ecoregions; nothing to do.\n"); quit(status = 0) }

nearest_donor <- function(e) covered[which.min(abs(covered - e))]
prov <- tibble(eco = covered, source = "native", donor = NA_integer_)
add_rows <- list()
for (e in missing) {
  donor <- if (!is.null(donor_override[[as.character(e)]])) donor_override[[as.character(e)]] else nearest_donor(e)
  if (!(donor %in% covered)) stop(sprintf("donor %d for eco %d is not in the baseline", donor, e))
  drows <- spp[as.integer(spp[[eco_col]]) == donor, , drop = FALSE]
  drows[[eco_col]] <- e
  add_rows[[as.character(e)]] <- drows
  prov <- bind_rows(prov, tibble(eco = e, source = "composed", donor = donor))
  cat(sprintf(" eco %d <- donor %d (%d species rows)\n", e, donor, nrow(drows)))
}
out <- bind_rows(spp, bind_rows(add_rows)) |> arrange(as.integer(.data[[eco_col]]))

if (APPLY) {
  bak <- sprintf("%s.backup_%s", BASE, format(Sys.Date(), "%Y%m%d"))
  if (!file.exists(bak)) file.copy(BASE, bak)
  write_csv(out, BASE)
  write_csv(prov |> arrange(eco), file.path(STDIR, ST, "inputs", "SppEcoregionData_provenance.csv"))
  cat(sprintf("\n APPLIED. baseline now covers: %s\n backup: %s\n provenance written.\n",
              paste(sort(unique(as.integer(out[[eco_col]]))), collapse = " "), bak))
  cat(" NOTE: composed ecoregions inherit a donor's productivity (documented assumption);\n")
  cat(" the harmonized FIA year-0 anchor rescales 2025 stock, so this mainly shapes post-2025 dynamics.\n")
} else {
  cat("\n DRY RUN (no files written). Re-run with --apply to write the baseline + provenance.\n")
}
