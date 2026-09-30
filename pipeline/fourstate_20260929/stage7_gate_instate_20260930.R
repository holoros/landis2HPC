# Stage 7 gate correction (session 32): share of active IC cells INSIDE the state polygon without an ecoregion.
# The first form of this gate counted active IC cells outside the state (the TreeMap clip is a padded bbox,
# stage 2 frac_inside_state 0.55 to 0.68), which LANDIS never simulates because the ecoregion map makes them inactive.
source("~/landis2_fb/scripts_20260929/gates_lib.R")
ST <- commandArgs(TRUE)[1]; IN <- file.path(FB, "states", ST, "inputs")
ic <- rast(file.path(IN, "initial-communities.tif")); e30 <- rast(file.path(IN, "ecoregions_20260929.tif"))
p <- state_poly(ST)
set.seed(20260930); n <- ncell(ic); idx <- sort(sample.int(n, min(2e6, n)))
xy <- xyFromCell(ic, idx); inside <- !is.na(extract(rasterize(p, ic, field = 1), xy)[, 1])
icv <- ic[idx][[1]]; ev <- e30[idx][[1]]
act_in <- !is.na(icv) & icv > 0 & inside
f <- mean(is.na(ev[act_in]) | ev[act_in] == 0)
act_out <- !is.na(icv) & icv > 0 & !inside
gate(ST, "stage7", "eco30:active_IC_inside_state_without_ecoregion", f <= 0.005,
     sprintf("%.5f of %d sampled active in-state cells", f, sum(act_in)), "<= 0.005", "2 M cell sample, seed 20260930, census 1:20M polygon")
gate(ST, "stage7", "eco30:active_IC_outside_state_all_inactive", mean(is.na(ev[act_out]) | ev[act_out] == 0) > 0.999,
     sprintf("%.4f of %d out-of-state active IC cells have no ecoregion", mean(is.na(ev[act_out]) | ev[act_out] == 0), sum(act_out)), "> 0.999", "LANDIS simulates only cells with an active ecoregion")
