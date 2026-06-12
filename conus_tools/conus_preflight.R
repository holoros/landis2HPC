#!/usr/bin/env Rscript
# conus_preflight.R
#
# CONUS readiness doctor for the harmonized per-plot LANDIS pipeline.
#
# Catches, before a statewide driver is ever launched, the silent-failure class
# that stalled WI and MI: a state whose plots fall in ecoregions that are not
# covered by its SppEcoregionData baseline or not handled by its
# build_plot_scenario script. Either produces header-only trajectory stubs with
# no error, so the run "completes" while generating nothing usable.
#
# For every state it cross-checks four facts:
#   1. plot ecoregions present        (tools/plot_to_ecoregion_<ST>.csv)
#   2. build-script ecoregion handling (tools/build_plot_scenario_<ST>.sh case)
#   3. baseline ecoregion coverage     (states/<ST>/inputs/SppEcoregionData.csv)
#   4. theta + apply_theta presence    (tools/apply_theta_<ST>_perspecies.py)
# and resolves each plot ecoregion to the model ecoregion the build maps it to,
# then confirms that model ecoregion is in the baseline.
#
# Usage:
#   Rscript conus_preflight.R [--root DIR] [--states WI,MI,...] [--out FILE.csv]
# Defaults: root = /fs/scratch/PUOM0008/crsfaaron/landis2 ; all states/ dirs.
#
# Output: a tidy CSV (one row per state x raw ecoregion) and a console PASS/FAIL
# summary that names every gap. Exit code 1 if any state FAILs (CI-friendly).

suppressMessages({
  library(dplyr); library(readr); library(stringr); library(tidyr); library(purrr)
})

## ---- args -----------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
get_opt <- function(flag, default = NA) {
  i <- which(args == flag)
  if (length(i) && i < length(args)) args[i + 1] else default
}
ROOT     <- get_opt("--root", "/fs/scratch/PUOM0008/crsfaaron/landis2")
STATES_A <- get_opt("--states", NA)
OUT      <- get_opt("--out", file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "conus_preflight_report.csv"))
if (is.na(OUT) || length(OUT) == 0 || OUT == "") OUT <- "conus_preflight_report.csv"

TOOLS  <- file.path(ROOT, "tools")
STDIR  <- file.path(ROOT, "states")

## ---- discover states ------------------------------------------------------
if (!is.na(STATES_A)) {
  states <- str_split(STATES_A, ",")[[1]] |> str_trim()
} else {
  states <- list.dirs(STDIR, recursive = FALSE, full.names = FALSE)
  states <- states[!str_detect(states, "_v[0-9]+$")]   # skip _v2 scratch variants
}

## ---- helpers --------------------------------------------------------------
# plot ecoregions present, with plot counts. Column 3 is the L3 eco code.
read_plot_ecos <- function(st) {
  f <- file.path(TOOLS, sprintf("plot_to_ecoregion_%s.csv", st))
  if (!file.exists(f)) return(NULL)
  d <- suppressWarnings(read_csv(f, show_col_types = FALSE, progress = FALSE))
  if (ncol(d) < 3) return(tibble(raw_eco = integer(), n_plots = integer()))
  ec <- suppressWarnings(as.integer(d[[3]]))
  tibble(raw_eco = ec) |> filter(!is.na(raw_eco), raw_eco > 0) |>
    count(raw_eco, name = "n_plots")
}

# build-script case map: raw_eco -> model_eco. Handles "3) ECO=2;" remaps and
# "51) ECO=51;" natives. Returns NULL when no per-plot build script exists.
read_build_map <- function(st) {
  f <- file.path(TOOLS, sprintf("build_plot_scenario_%s.sh", st))
  if (!file.exists(f)) return(NULL)
  ln <- readLines(f, warn = FALSE)
  m  <- str_match(ln, "^\\s*([0-9]+)\\)\\s*ECO=([0-9]+)\\s*;")
  m  <- m[!is.na(m[, 1]), , drop = FALSE]
  if (!nrow(m)) return(tibble(raw_eco = integer(), model_eco = integer()))
  tibble(raw_eco = as.integer(m[, 2]), model_eco = as.integer(m[, 3])) |> distinct()
}

# baseline ecoregions covered. Column 2 (EcoregionName) carries the numeric code.
read_baseline_ecos <- function(st) {
  f <- file.path(STDIR, st, "inputs", "SppEcoregionData.csv")
  if (!file.exists(f)) return(NULL)
  d <- suppressWarnings(read_csv(f, show_col_types = FALSE, progress = FALSE))
  if (ncol(d) < 2) return(integer())
  sort(unique(suppressWarnings(as.integer(d[[2]]))))
}

has_theta_tool <- function(st) file.exists(file.path(TOOLS, sprintf("apply_theta_%s_perspecies.py", st)))
# Shallow glob only (one level under bayesian/); recursive scans of MCMC trees hang.
theta_csv <- function(st) {
  hits <- Sys.glob(file.path(STDIR, st, "perseus", "bayesian", "*", "theta_best_production.csv"))
  if (length(hits)) hits[1] else NA_character_
}

## ---- per-state assessment -------------------------------------------------
assess_state <- function(st) {
  pe  <- read_plot_ecos(st)
  bm  <- read_build_map(st)
  bse <- read_baseline_ecos(st)
  has_build    <- !is.null(bm)
  has_plotlist <- !is.null(pe)
  has_baseline <- !is.null(bse)

  if (!has_plotlist) {
    return(tibble(state = st, raw_eco = NA_integer_, n_plots = NA_integer_,
                  build_handled = NA, model_eco = NA_integer_,
                  in_baseline = NA, status = "NO_PLOTLIST"))
  }
  if (nrow(pe) == 0) {
    return(tibble(state = st, raw_eco = NA_integer_, n_plots = 0L,
                  build_handled = NA, model_eco = NA_integer_,
                  in_baseline = NA, status = "EMPTY_PLOTLIST"))
  }

  out <- pe |>
    mutate(
      build_handled = if (has_build) raw_eco %in% bm$raw_eco else NA,
      model_eco = if (has_build) bm$model_eco[match(raw_eco, bm$raw_eco)] else raw_eco,
      in_baseline = if (has_baseline) model_eco %in% bse else NA
    ) |>
    mutate(status = case_when(
      !has_baseline                          ~ "NO_BASELINE",
      has_build & !build_handled             ~ "BUILD_UNHANDLED",   # would hit *) ERROR unknown eco
      is.na(model_eco)                       ~ "BUILD_UNHANDLED",
      !in_baseline                           ~ "BASELINE_GAP",      # builds, but empty SppEcoregionData -> silent stub
      TRUE                                   ~ "OK"
    ))
  out$state <- st
  out |> select(state, raw_eco, n_plots, build_handled, model_eco, in_baseline, status)
}

report <- map_dfr(states, assess_state)

## ---- state-level rollup ---------------------------------------------------
meta <- tibble(state = states,
               has_build    = map_lgl(states, ~!is.null(read_build_map(.x))),
               has_theta    = map_lgl(states, has_theta_tool),
               theta_file   = map_chr(states, ~{f <- theta_csv(.x); ifelse(is.na(f), "MISSING", "present")}))

state_status <- report |>
  group_by(state) |>
  summarise(
    n_eco        = sum(!is.na(raw_eco)),
    n_plots      = sum(n_plots, na.rm = TRUE),
    build_gaps   = sum(status == "BUILD_UNHANDLED", na.rm = TRUE),
    baseline_gaps= sum(status == "BASELINE_GAP", na.rm = TRUE),
    blockers     = paste(sort(unique(status[status != "OK"])), collapse = ","),
    .groups = "drop"
  ) |>
  left_join(meta, by = "state") |>
  mutate(verdict = if_else(build_gaps == 0 & baseline_gaps == 0 &
                             !blockers %in% c("NO_BASELINE", "NO_PLOTLIST") &
                             has_theta, "PASS", "FAIL"))

## ---- write + print --------------------------------------------------------
write_csv(report, OUT)

cat("\n================ CONUS PER-PLOT PIPELINE PREFLIGHT ================\n")
cat(sprintf("root: %s   states: %d   report: %s\n\n", ROOT, length(states), OUT))

fmt_gaps <- function(st, kind) {
  g <- report |> filter(state == st, status == kind)
  if (!nrow(g)) return("")
  paste0(g$raw_eco, if (kind == "BASELINE_GAP") paste0("(->", g$model_eco, ")") else "",
         "[", g$n_plots, "p]") |> paste(collapse = " ")
}

for (i in seq_len(nrow(state_status))) {
  s <- state_status[i, ]
  mark <- if (s$verdict == "PASS") "PASS" else "FAIL"
  cat(sprintf("[%s] %-5s  %d ecoregions, %d plots  build:%s theta:%s\n",
              mark, s$state, s$n_eco, s$n_plots,
              ifelse(s$has_build, "Y", "-"), ifelse(s$has_theta, "Y", "-")))
  if (s$blockers != "") cat(sprintf("        blockers: %s\n", s$blockers))
  bu <- fmt_gaps(s$state, "BUILD_UNHANDLED"); if (bu != "") cat(sprintf("        build cannot handle eco: %s\n", bu))
  bg <- fmt_gaps(s$state, "BASELINE_GAP");    if (bg != "") cat(sprintf("        baseline missing eco:    %s\n", bg))
  if (s$theta_file == "MISSING" && s$has_theta) cat("        theta_best_production.csv: NOT FOUND\n")
}

n_fail <- sum(state_status$verdict == "FAIL")
cat(sprintf("\n%d PASS, %d FAIL\n", sum(state_status$verdict == "PASS"), n_fail))
cat("Remediate BASELINE_GAP with compose_sppeco_baseline.R; BUILD_UNHANDLED by\n")
cat("adding the raw->model mapping (build_plot_scenario_TEMPLATE.sh reads it from a crosswalk).\n")
cat("==================================================================\n")

quit(status = if (n_fail > 0) 1 else 0)
