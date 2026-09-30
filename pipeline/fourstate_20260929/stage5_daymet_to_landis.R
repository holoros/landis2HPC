#!/usr/bin/env Rscript
# stage5_daymet_to_landis.R: daily Daymet -> monthly (precip = monthly sum mm, mintemp/maxtemp = monthly mean
# of daily tmin/tmax degC) -> mean across the sample points of each L3 ecoregion -> LANDIS wide climate table
# Year,Month,Variable,<L3 codes> in the ME template schema (rows precip, mintemp, maxtemp per month).
# Daymet uses a 365-day year (Dec 31 dropped in leap years). Usage: Rscript stage5_daymet_to_landis.R <ST>
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
ST <- commandArgs(TRUE)[1]
C <- file.path(FB, "daymet_cache", ST)
P <- fread(file.path(C, sprintf("sample_points_%s_seed20260929.csv", ST)))
codes <- list(NH = c(58, 59), VT = c(58, 59, 83), MI = c(50, 51, 55, 56, 57), WI = c(47, 50, 51, 52, 53, 54))[[ST]]
L <- list()
for (i in seq_len(nrow(P))) {
  f <- file.path(C, sprintf("dm_%s_eco%d_pt%03d.csv", ST, P$eco[i], P$pt[i]))
  if (!file.exists(f)) next
  hl <- grep("^year,yday", readLines(f, n = 30))
  d <- fread(f, skip = hl - 1); setnames(d, c("year", "yday", "prcp", "tmax", "tmin"))
  d[, month := as.integer(format(as.Date(sprintf("%d-01-01", year)) + yday - 1, "%m"))]
  m <- d[, .(precip = sum(prcp), mintemp = mean(tmin), maxtemp = mean(tmax), ndays = .N), by = .(year, month)]
  m[, `:=`(pt = P$pt[i], eco = P$eco[i])]; L[[length(L) + 1]] <- m
}
M <- rbindlist(L)
gate(ST, "stage5", "daymet_points_fetched", uniqueN(M$pt) == nrow(P), paste(uniqueN(M$pt), "of", nrow(P)), "all sample points", "fetch completeness")
E <- M[, .(precip = mean(precip), mintemp = mean(mintemp), maxtemp = mean(maxtemp), npt = .N), by = .(eco, year, month)]
long <- melt(E, id.vars = c("eco", "year", "month", "npt"), variable.name = "Variable")
wide <- dcast(long, year + month + Variable ~ eco, value.var = "value")
setnames(wide, c("year", "month"), c("Year", "Month"))
wide[, Variable := factor(Variable, levels = c("precip", "mintemp", "maxtemp"))]; setorder(wide, Year, Month, Variable)
ec <- setdiff(names(wide), c("Year", "Month", "Variable"))
wide[, (ec) := lapply(.SD, function(x) round(x, 4)), .SDcols = ec]
outp <- beside(file.path(FB, "states", ST, "inputs", sprintf("Daymet_%s_l3.csv", ST)))
fwrite(wide, outp)
cat("wrote", outp, "md5", tools::md5sum(outp), "\n")
gate(ST, "stage5", "daymet_columns_equal_stage1_codes", setequal(as.integer(ec), codes), paste(ec, collapse = " "), paste(codes, collapse = " "), "stage one L3 codes")
gate(ST, "stage5", "daymet_complete", nrow(wide) == 30 * 12 * 3 && !anyNA(wide), nrow(wide), "1080 rows, no NA", "1991-2020 x 12 months x 3 variables")
w <- as.matrix(wide[, ..ec])
pr <- w[wide$Variable == "precip", ]; tn <- w[wide$Variable == "mintemp", ]; tx <- w[wide$Variable == "maxtemp", ]
gate(ST, "stage5", "precip_range_mm_month", min(pr) >= 0 && max(pr) <= 600, sprintf("%.1f..%.1f", min(pr), max(pr)), "[0,600] mm/month", "physical bound for the NE and Lake States")
gate(ST, "stage5", "tmin_range", min(tn) >= -40 && max(tn) <= 30, sprintf("%.1f..%.1f", min(tn), max(tn)), "[-40,30] C", "physical bound (monthly mean)")
gate(ST, "stage5", "tmax_range", min(tx) >= -30 && max(tx) <= 40, sprintf("%.1f..%.1f", min(tx), max(tx)), "[-30,40] C", "physical bound (monthly mean)")
gate(ST, "stage5", "tmin_lt_tmax", all(tn < tx), sprintf("min(tmax-tmin)=%.2f", min(tx - tn)), "tmin < tmax everywhere", "physical")
ann <- wide[Variable == "precip", lapply(.SD, sum), by = Year, .SDcols = ec][, lapply(.SD, mean), .SDcols = ec]
cat("mean annual precip (mm) by eco:", paste(names(ann), round(unlist(ann)), collapse = "; "), "\n")
cat("points per eco:", paste(E[, .(n = max(npt)), by = eco][, paste0(eco, "=", n)], collapse = " "), "\n")
