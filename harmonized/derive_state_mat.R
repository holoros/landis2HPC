# Derive per-state mean annual temperature (degC) from PRISM 30-yr monthly normals,
# for the GCBM CONUS input tiler (replaces Maine's hardcoded 5.67 degC).
# MAT = mean of 12 monthly tmean normals, averaged over the state boundary.
suppressPackageStartupMessages({library(terra); library(data.table)})
PR <- "/users/PUOM0008/crsfaaron/fia_data/climate/prism"
ST_SHP <- "/users/PUOM0008/crsfaaron/Disturbance/cb_2023_us_state_20m.shp"
states <- vect(ST_SHP)
mon <- sprintf("2020%02d", 1:12)
tmean_files <- sapply(mon, function(m)
  file.path(PR, sprintf("prism_tmean_us_25m_%s_avg_30y", m),
            sprintf("prism_tmean_us_25m_%s_avg_30y.tif", m)))
mat <- mean(rast(tmean_files))                     # 12-month mean = MAT raster
out <- rbindlist(lapply(c("MN","WA","OR","CA","GA"), function(ST){
  s <- states[states$STUSPS == ST, ]
  sp <- project(s, crs(mat))
  m <- crop(mat, sp); m <- mask(m, sp)
  data.table(state = ST, mat_degC = round(as.numeric(global(m, "mean", na.rm = TRUE)), 2))
}))
fwrite(out, "/fs/scratch/PUOM0008/crsfaaron/FIA/state_mat_prism.csv")
print(out)
