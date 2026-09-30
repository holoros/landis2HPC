#!/usr/bin/env Rscript
# stage5_gates_synthetic.R <ST>: gates on the delta-method future tables (build_synthetic_cmip6_fb.py).
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
ST <- commandArgs(TRUE)[1]; IN <- file.path(FB, "states", ST, "inputs")
h <- fread(file.path(IN, sprintf("Daymet_%s_l3.csv", ST)))
ec <- setdiff(names(h), c("Year", "Month", "Variable"))
base <- h[, lapply(.SD, mean), by = .(Month, Variable), .SDcols = ec]
for (sc in c("ssp245", "ssp585")) {
  f <- file.path(IN, sprintf("HadGEM3_%s_%s_l3.csv", sc, ST)); f2 <- sub("[.]csv$", "_20260929.csv", f)
  if (file.exists(f2)) f <- f2
  x <- fread(f); cat("md5", tools::md5sum(f), f, "\n")
  gate(ST, "stage5", paste0(sc, ":shape"), nrow(x) == 91 * 12 * 3 && setequal(setdiff(names(x), c("Year", "Month", "Variable")), ec) && !anyNA(x),
       paste(nrow(x), "rows"), "3276 rows (2010-2100 x 12 x 3), same L3 columns, no NA", "build_synthetic_cmip6 schema")
  dT <- c(ssp245 = 2.5, ssp585 = 4.5)[sc]; dP <- c(ssp245 = 1.05, ssp585 = 1.10)[sc]
  b <- merge(x[Year == 2100], base, by = c("Month", "Variable"), suffixes = c("", ".b"))
  dt <- sapply(ec, function(e) b[Variable != "precip", max(abs(get(e) - get(paste0(e, ".b")) - dT))])
  dp <- sapply(ec, function(e) b[Variable == "precip", max(abs(get(e) / get(paste0(e, ".b")) - dP))])
  gate(ST, "stage5", paste0(sc, ":endpoint_delta"), max(dt) < 1e-3 && max(dp) < 1e-3, sprintf("max |dT err| %.2e, max |dP err| %.2e", max(dt), max(dp)),
       sprintf("2100 = baseline + %.1f C, x %.2f precip", dT, dP), "IPCC AR6 CONUS endpoint deltas coded in build_synthetic_cmip6.*")
}
