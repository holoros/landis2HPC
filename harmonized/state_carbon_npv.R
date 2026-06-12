#!/usr/bin/env Rscript
# state_carbon_npv.R
#
# Pairs the harmonized LANDIS carbon scenarios with timber NPV per state, so
# carbon (physical) and economics (dollars) sit on SEPARATE axes (per the
# multi-criteria framework recommendation; the file's npv_rev/npv_net columns
# fold in a carbon valuation and are not pure timber).
#
# Timber NPV per ha = (ann_timber / area_ha) * annuity(d, horizon)
#   ann_timber, area_ha from ecoregion_npv_by_rate.csv (per L3 ecoregion x scenario)
#   area-weighted to state by plot-share from plot_to_ecoregion_{ST}.csv
#   ecoregion code crosswalk US_L3CODE <-> NA_L3CODE from us_eco_l3.shp
#
# Output: harmonized_carbon_npv_4state.csv (state, scenario, carbon_2100_TgC,
#         npv_timber_perha_0.03, npv_timber_perha_0.05)
# module load gcc/12.3.0; module load gdal/.. geos/.. proj/..; module load R/4.4.0

suppressPackageStartupMessages({ library(data.table); library(terra) })
S      <- "/fs/scratch/PUOM0008/crsfaaron"
tools  <- file.path(S, "landis2/tools")
HORIZON <- 75
annuity <- function(d, n = HORIZON) (1 - (1+d)^(-n)) / d

# ecoregion code crosswalk
xw <- unique(as.data.table(as.data.frame(vect(file.path("/users/PUOM0008/crsfaaron/Disturbance/us_eco_l3.shp"))))[, .(US_L3CODE, NA_L3CODE)])
xw[, US_L3CODE := as.integer(US_L3CODE)]

npv <- fread(file.path(S, "ecoregion_npv_by_rate.csv"))
npv <- npv[, .(NA_L3CODE, scenario, ann_timber, area_ha)]
npv[, timber_perha_yr := ann_timber / area_ha]
scen_map <- c("reserve (no harvest)"="reserve", "managed (conservation)"="conservation",
              "managed (harvest)"="BAU", "managed (intensive)"="intensive")
npv[, scen := scen_map[scenario]]

FIPS <- c(WA=53, MN=27, IN=18, OH=39)
states <- names(FIPS)

st_npv <- rbindlist(lapply(states, function(st) {
  pe <- fread(file.path(tools, paste0("plot_to_ecoregion_", st, ".csv")))
  setnames(pe, 3, "eco")                               # 3rd col is the L3 code (eco | eco_l3)
  w  <- pe[eco > 0, .(n = .N), by = .(US_L3CODE = as.integer(eco))]
  w  <- merge(w, xw, by = "US_L3CODE")               # -> NA_L3CODE
  d  <- merge(w, npv, by = "NA_L3CODE", allow.cartesian = TRUE)
  r  <- d[, .(npv_timber_perha_0.03 = round(weighted.mean(timber_perha_yr, n) * annuity(0.03)),
              npv_timber_perha_0.05 = round(weighted.mean(timber_perha_yr, n) * annuity(0.05))),
          by = .(scenario = scen)]
  r[, state := st][]
}))

# join carbon (2100) from the harmonized scenario table
carb <- fread(file.path(S, "FIA/harmonized_landis_4scenario.csv"))
fips2abbr <- setNames(names(FIPS), sprintf("%02d", FIPS))
carb <- carb[year == 2100, .(state = fips2abbr[sprintf("%02d", as.integer(dom))],
                             scenario, carbon_2100_TgC = round(agc_TgC,1))]

out <- merge(carb, st_npv, by = c("state","scenario"))
setorder(out, state, -carbon_2100_TgC)
fwrite(out, file.path(S, "FIA/harmonized_carbon_npv_4state.csv"))
print(out)
