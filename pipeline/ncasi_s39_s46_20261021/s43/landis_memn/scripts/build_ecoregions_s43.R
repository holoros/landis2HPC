# s43 Track A step 3: 30 m ecoregion layers for ME and MN on the TreeMap state grid (explicit, logged resampling).
# Mirror check first: was NH/MI ecoregions_20260929.tif (30 m, TM grid) a nearest-neighbour resample of the
# state's 270 m Level III raster (ecoregions_l3_270m_20260928.tif)? Agreement is logged.
suppressMessages({library(terra); library(data.table)})
terraOptions(memfrac = 0.7, progress = 0)
L <- "/fs/scratch/PUOM0008/crsfaaron/landis2"; D <- file.path(L, "states_fb_20260930")
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn"; O <- file.path(T, "out"); dir.create(O, showWarnings = FALSE)
lg <- function(...) { s <- paste(format(Sys.time(), "%H:%M:%S"), ...); cat(s, "\n"); cat(s, "\n", file = file.path(T, "logs/ecoregions_s43.log"), append = TRUE) }
geo <- function(r) sprintf("%dx%d origin(%.3f,%.3f) res(%.3f,%.3f) crs %s", ncol(r), nrow(r), xmin(r), ymax(r), res(r)[1], res(r)[2], crs(r, describe = TRUE)$code)
km2 <- function(r) { f <- as.data.table(freq(r)); f[, km2 := count * prod(res(r)) / 1e6]; f[, .(value, km2 = round(km2, 1))] }
chk <- list()
for (st in c("NH", "MI")) {
  e30 <- rast(file.path(D, st, "inputs/ecoregions_20260929.tif")); e270 <- rast(file.path(D, st, "inputs/ecoregions_l3_270m_20260928.tif"))
  rs <- resample(e270, e30, method = "near")
  a <- values(e30)[, 1]; b <- values(rs)[, 1]; a[a == 0] <- NA; b[b == 0] <- NA
  both <- !is.na(a) & !is.na(b); either <- !is.na(a) | !is.na(b)
  chk[[st]] <- data.table(state = st, cells_30 = sum(!is.na(a)), cells_rs = sum(!is.na(b)), agree_in_either = sum(both & a == b) / sum(either),
                          agree_in_both = sum(a[both] == b[both]) / sum(both))
  lg("MIRROR", st, "30m:", geo(e30), "| 270m:", geo(e270)); print(chk[[st]]); rm(a, b, rs); gc()
}
fwrite(rbindlist(chk), file.path(O, "ecoregion_mirror_check_s43.csv"))
build <- function(st, src, tag) {
  tm <- rast(file.path(L, "states", st, "inputs", paste0(st, "_TM_22.tif"))); levels(tm) <- NULL
  s <- rast(src)
  lg(st, tag, "TM grid:", geo(tm)); lg(st, tag, "source:", src, geo(s))
  lg(st, tag, "same CRS:", same.crs(tm, s))
  r <- resample(s, tm, method = "near")
  r <- classify(r, cbind(NA, 0)); r[r < 0] <- 0
  f <- file.path(O, sprintf("ecoregions_s43_%s_%s.tif", st, tag))
  writeRaster(r, f, datatype = "INT2U", NAflag = 0, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
  r2 <- rast(f); lg(st, tag, "written:", f, geo(r2), "compareGeom with TM:", compareGeom(r2, tm, stopOnError = FALSE))
  k <- km2(r2); k <- k[value > 0]; lg(st, tag, "km2 by code:", paste(k$value, k$km2, sep = "=", collapse = " "), "total", sum(k$km2))
  k[, `:=`(state = st, tag = tag, source = basename(src), method = "near")]
  k
}
res <- rbind(
  build("ME", file.path(L, "states/ME/inputs/ME_ecoregion_l3_270m_20260925.tif"), "from270"),
  build("ME", file.path(L, "states/ME/inputs/ME_ecoregion_l3.tif"), "from30fm"),
  build("MN", file.path(L, "states/MN/inputs/MN_ecoregion_l3.tif"), "from30"))
fwrite(res, file.path(O, "ecoregion_build_s43.csv"))
# ME from270 vs from30fm agreement where both coded
a <- values(rast(file.path(O, "ecoregions_s43_ME_from270.tif")))[, 1]; b <- values(rast(file.path(O, "ecoregions_s43_ME_from30fm.tif")))[, 1]
both <- a > 0 & b > 0; lg("ME from270 vs from30fm: cells both", sum(both), "agree", round(mean(a[both] == b[both]), 5), "from30fm cells not in from270", sum(b > 0 & !(a > 0)))
lg("DONE")
