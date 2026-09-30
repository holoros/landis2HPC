# Stage 7a (session 32, 30 Sep 2026): ecoregions_20260929.tif at 30 m on the exact initial-communities grid,
# nearest resampled from the 270 m stage one raster, plus ecoregions_20260929.txt. Installed beside, never over.
suppressMessages(library(terra)); suppressMessages(library(data.table))
ST <- commandArgs(TRUE)[1]; IN <- file.path("~/landis2_fb/states", ST, "inputs")
ic <- rast(file.path(IN, "initial-communities.tif"))
e270 <- rast(file.path(IN, "ecoregions_l3_270m_20260928.tif"))
stopifnot(crs(ic, describe=TRUE)$code == crs(e270, describe=TRUE)$code)
out <- file.path(IN, "ecoregions_20260929.tif")
e30 <- resample(e270, ic, method = "near", filename = out, overwrite = TRUE, datatype = "INT2U", NAflag = 0, wopt = list(gdal = c("COMPRESS=LZW")))
e30 <- rast(out)
# gates
g <- list()
g$same_grid <- compareGeom(e30, ic, stopOnError = FALSE)
codes <- sort(unique(na.omit(as.vector(unique(e30)[[1]]))))
c270 <- sort(unique(na.omit(as.vector(unique(e270)[[1]]))))
g$codes <- paste(codes, collapse = " "); g$codes_equal_stage1 <- identical(codes, c270)
# NA share under active IC cells, on a 2 M cell sample
set.seed(20260930); n <- ncell(ic); idx <- sort(sample.int(n, min(2e6, n)))
icv <- ic[idx][[1]]; ev <- e30[idx][[1]]
act <- !is.na(icv) & icv > 0
g$ic_active_sampled <- sum(act); g$frac_active_without_eco <- mean(is.na(ev[act]) | ev[act] == 0)
# txt
cand <- file.path(IN, "ecoregions_candidate_20260928.txt"); txt <- readLines(cand)
tc <- as.integer(sub("^yes\t([0-9]+)\t.*", "\\1", grep("^yes", txt, value = TRUE)))
g$txt_codes_equal_raster <- setequal(tc, codes)
writeLines(txt, file.path(IN, "ecoregions_20260929.txt"))
gl <- file("~/landis2_fb/gates_20260929.tsv", "a"); ts <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
w <- function(gate, res, val, thr, prov) cat(ts, ST, "stage7", gate, res, val, thr, prov, sep = "\t", file = gl); 
w2 <- function(...) { w(...); cat("\n", file = gl) }
w2("eco30:same_grid_as_IC", if (isTRUE(g$same_grid)) "PASS" else "FAIL", "compareGeom", "identical grid", "terra::resample near onto initial-communities.tif")
w2("eco30:codes_equal_stage1", if (g$codes_equal_stage1) "PASS" else "FAIL", g$codes, paste(c270, collapse = " "), "stage one raster codes")
w2("eco30:active_IC_without_ecoregion", if (g$frac_active_without_eco <= 0.005) "PASS" else "FAIL", sprintf("%.5f of %d sampled active cells", g$frac_active_without_eco, g$ic_active_sampled), "<= 0.005", "2 M cell sample, seed 20260930")
w2("eco30:txt_matches_raster", if (g$txt_codes_equal_raster) "PASS" else "FAIL", paste(tc, collapse = " "), g$codes, "ecoregions_20260929.txt yes rows")
close(gl); print(g); cat("STAGE7A_DONE", ST, "\n")
