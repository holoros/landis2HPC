# Session 34, 3 Oct 2026. Gates and growth decomposition for the MI and WI calibrated table smoke
# (smoke_20261003_d10_unitfix_t2cal) against the 1 Oct unit corrected smoke (smoke_20261001_d10_unitfix).
# Same code computes both runs, so the comparison does not depend on the 1 Oct gate script.
# Gates: G8.1 log says complete with no ERROR or Exception; G8.2 LANDIS active sites equal the build;
# G8.3x year zero equals the 1 Oct unit fix year zero (same IC, so it must, to 0.1 percent).
# Diagnostics: landscape, per ecoregion and per species ten year ratio, both runs.
# Cell area from build_summary.csv CellLength (LANDIS rasters carry no georeferencing).
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
runs <- c(base = "smoke_20261001_d10_unitfix", t2cal = "smoke_20261003_d10_unitfix_t2cal")
gates <- list(); dec <- list()
for (st in c("MI", "WI")) {
  for (k in names(runs)) {
    R <- file.path(D, st, "runs", runs[[k]])
    lg <- readLines(file.path(R, "Landis-log.txt"), warn = FALSE)
    bs <- fread(file.path(R, "build_summary.csv")); cell <- bs$cell_m
    done <- any(grepl("Model run is complete", lg)); errs <- grep("ERROR|Exception", lg, value = TRUE)
    al <- grep("Sites: .* active", lg, value = TRUE)[1]
    act <- as.numeric(gsub(",", "", sub(".*Sites: ([0-9,]+) active.*", "\\1", al)))
    gates[[length(gates) + 1]] <- data.table(state = st, run = k,
      G8.1 = if (done && !length(errs)) "PASS" else "FAIL",
      G8.2 = if (!is.na(act) && act == bs$active_cells) "PASS" else "CHECK")
    eco <- values(rast(file.path(R, "ecoregions.tif")))[, 1]
    spp <- sub("^biomass-(.*)-0\\.tif$", "\\1", list.files(file.path(R, "output/biomass"), "-0\\.tif$"))
    spp <- setdiff(spp, c("TotalBiomass", "woody", "non-woody", "dead"))
    for (s in spp) {
      v0 <- values(rast(file.path(R, "output/biomass", sprintf("biomass-%s-0.tif", s))))[, 1]
      v10 <- values(rast(file.path(R, "output/biomass", sprintf("biomass-%s-10.tif", s))))[, 1]
      ok <- !is.na(eco) & eco > 0
      dt <- data.table(eco = eco[ok], b0 = v0[ok], b10 = v10[ok])[, .(b0 = sum(b0, na.rm = TRUE), b10 = sum(b10, na.rm = TRUE)), by = eco]
      dt[, `:=`(state = st, run = k, species = s, b0_Tg = b0 * cell^2 / 1e12, b10_Tg = b10 * cell^2 / 1e12)]
      dec[[length(dec) + 1]] <- dt[, .(state, run, eco, species, b0_Tg, b10_Tg)]
    }
    rm(eco); gc()
  }
}
G <- rbindlist(gates); X <- rbindlist(dec)
land <- X[, .(b0 = sum(b0_Tg), b10 = sum(b10_Tg)), by = .(state, run)][, ratio := round(b10 / b0, 3)]
y0 <- dcast(land, state ~ run, value.var = "b0")
y0[, G8.3x := fifelse(abs(t2cal / base - 1) < 0.001, "PASS", "FAIL")]
byeco <- X[, .(b0 = sum(b0_Tg), b10 = sum(b10_Tg)), by = .(state, run, eco)][, ratio := round(b10 / b0, 3)]
byspp <- X[, .(b0 = sum(b0_Tg), b10 = sum(b10_Tg)), by = .(state, run, species)][, ratio := round(b10 / b0, 3)]
O <- file.path(D, "gates")
fwrite(G, file.path(O, "t2cal_gates_20261003.csv")); fwrite(land, file.path(O, "t2cal_landscape_20261003.csv"))
fwrite(y0, file.path(O, "t2cal_year0_check_20261003.csv"))
fwrite(dcast(byeco, state + eco ~ run, value.var = "ratio"), file.path(O, "t2cal_by_ecoregion_20261003.csv"))
top <- byspp[run == "base"][order(state, -b0)][, head(.SD, 8), by = state]
fwrite(dcast(byspp[species %in% top$species], state + species ~ run, value.var = "ratio"),
       file.path(O, "t2cal_by_species_20261003.csv"))
print(G); print(land); print(y0); print(dcast(byeco, state + eco ~ run, value.var = "ratio"))
print(dcast(byspp[species %in% top$species], state + species ~ run, value.var = "ratio"))
