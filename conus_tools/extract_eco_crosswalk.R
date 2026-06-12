#!/usr/bin/env Rscript
# extract_eco_crosswalk.R
#
# Captures the implicit ecoregion handling that currently lives inside each
# build_plot_scenario_<ST>.sh case block and writes it out as explicit data:
# tools/eco_crosswalk_<ST>.csv with columns raw_eco, model_eco, eco_name, kind.
#
# kind is "native" when raw_eco == model_eco and "remap" when the build maps a
# raw plot ecoregion onto a different calibrated model ecoregion (the pattern WA
# uses for ecoregions 3 and 15). Making this a CSV gives the preflight, the
# composer, and the generalized build a single source of truth, and lets a new
# state be onboarded by editing data instead of shell code.
#
# Usage: Rscript extract_eco_crosswalk.R [--root DIR] [--states WA,OH,...] [--apply]
# Without --apply it prints what it would write.

suppressMessages({ library(dplyr); library(readr); library(stringr); library(purrr) })

args <- commandArgs(trailingOnly = TRUE)
opt <- function(flag, default = NA) { i <- which(args == flag); if (length(i) && i < length(args)) args[i + 1] else default }
has <- function(flag) flag %in% args
ROOT <- opt("--root", "/fs/scratch/PUOM0008/crsfaaron/landis2")
TOOLS <- file.path(ROOT, "tools"); STDIR <- file.path(ROOT, "states")
APPLY <- has("--apply")
HERE  <- tryacc <- {
  f <- grep("--file=", commandArgs(FALSE), value = TRUE)[1]
  if (!is.na(f)) normalizePath(dirname(sub("--file=", "", f))) else "."
}
names_csv <- file.path(HERE, "ecoregion_names.csv")
if (!file.exists(names_csv)) names_csv <- file.path(TOOLS, "..", "conus_tools", "ecoregion_names.csv")
NAMES <- if (file.exists(names_csv)) read_csv(names_csv, show_col_types = FALSE) else tibble(eco_code = integer(), eco_name = character())

states <- if (!is.na(opt("--states", NA))) str_split(opt("--states"), ",")[[1]] |> str_trim() else {
  s <- list.dirs(STDIR, recursive = FALSE, full.names = FALSE); s[!str_detect(s, "_v[0-9]+$")]
}

extract_one <- function(st) {
  bf <- file.path(TOOLS, sprintf("build_plot_scenario_%s.sh", st))
  if (!file.exists(bf)) { cat(sprintf("[%s] no build script, skipping\n", st)); return(invisible()) }
  ln <- readLines(bf, warn = FALSE)
  # capture raw) ECO=model; ECO_NAME='"Name"' (name optional)
  m  <- str_match(ln, "^\\s*([0-9]+)\\)\\s*ECO=([0-9]+)\\s*;(?:\\s*ECO_NAME='\"([^\"]*)\"')?")
  m  <- m[!is.na(m[, 1]), , drop = FALSE]
  if (!nrow(m)) { cat(sprintf("[%s] no case entries found\n", st)); return(invisible()) }
  tab <- tibble(raw_eco = as.integer(m[, 2]), model_eco = as.integer(m[, 3]),
                eco_name = m[, 4]) |> distinct() |> arrange(raw_eco)
  # fill any missing names from the central table
  tab <- tab |>
    mutate(eco_name = ifelse(is.na(eco_name) | eco_name == "",
                             NAMES$eco_name[match(model_eco, NAMES$eco_code)], eco_name),
           kind = if_else(raw_eco == model_eco, "native", "remap"))
  out <- file.path(TOOLS, sprintf("eco_crosswalk_%s.csv", st))
  cat(sprintf("[%s] %d entries (%d remap)%s\n", st, nrow(tab), sum(tab$kind == "remap"),
              if (APPLY) sprintf(" -> %s", out) else " (dry run)"))
  if (APPLY) write_csv(tab, out)
  invisible(tab)
}

walk(states, extract_one)
if (!APPLY) cat("\nDry run. Re-run with --apply to write tools/eco_crosswalk_<ST>.csv.\n")
