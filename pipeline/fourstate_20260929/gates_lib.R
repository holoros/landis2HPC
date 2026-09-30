# gates_lib.R  (landis2_fb scripts_20260929)
# Hard gate helpers. Every gate prints PASS or FAIL with its threshold provenance
# and appends one TSV row to the gate log. A FAIL is reported, never worked around.
suppressPackageStartupMessages({ library(terra); library(data.table) })

FB      <- path.expand("~/landis2_fb")
STAGE1  <- path.expand("~/jobs/landis_stage1_20260928")
STATE_SHP <- file.path(STAGE1, "gis", "cb_2023_us_state_20m.shp")
GATE_LOG <- Sys.getenv("GATE_LOG", file.path(FB, "gates_20260929.tsv"))

gate <- function(st, stage, name, ok, value, threshold, provenance) {
  res <- if (isTRUE(ok)) "PASS" else "FAIL"
  cat(sprintf("%s | %s | %s | %s | value=%s | threshold=%s | provenance=%s\n",
              res, st, stage, name, value, threshold, provenance))
  row <- data.table(time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), state = st, stage = stage,
                    gate = name, result = res, value = as.character(value),
                    threshold = threshold, provenance = provenance)
  fwrite(row, GATE_LOG, sep = "\t", append = file.exists(GATE_LOG))
  invisible(isTRUE(ok))
}

state_poly <- function(st, crs_to = "EPSG:5070") {
  s <- vect(STATE_SHP)
  p <- s[s$STUSPS == st, ]
  if (nrow(p) != 1) stop("state polygon not found: ", st)
  project(p, crs_to)
}

stage1_eco <- function(st) rast(file.path(STAGE1, "out", st, "ecoregions_l3_270m_20260928.tif"))

is5070 <- function(r) {
  d <- crs(r, describe = TRUE)
  code_ok <- !is.na(d$code) && d$code == "5070" && identical(toupper(d$authority), "EPSG")
  code_ok || same.crs(r, "EPSG:5070")
}

# Write beside, never over: if target exists, return a dated variant path.
beside <- function(path, tag = "20260929") {
  if (!file.exists(path)) return(path)
  ext <- tools::file_ext(path); stem <- sub(paste0("\\.", ext, "$"), "", path)
  p2 <- paste0(stem, "_", tag, ".", ext)
  if (file.exists(p2)) stop("dated variant already exists, refusing to overwrite: ", p2)
  message("NOTE target exists, writing dated variant: ", p2)
  p2
}

# Standard raster gates. poly: state polygon in raster CRS.
#  inside_min: minimum fraction of valid cells whose centres fall inside the state polygon
#  reach_min : minimum fraction of state polygon covered (reach_mode valid: by non-NA cells; extent: by raster extent)
raster_gates <- function(st, stage, label, r, poly, res_expect, vmin, vmax,
                         inside_min, inside_prov, reach_min = NA, reach_prov = "",
                         reach_mode = "valid") {
  gate(st, stage, paste0(label, ":crs"), is5070(r), crs(r, describe = TRUE)$code, "EPSG:5070",
       "LANDIS run CRS used by ME/MN templates and stage one (clip_state_ecoregions.R)")
  gate(st, stage, paste0(label, ":res"), all(abs(res(r) - res_expect) < 1e-6),
       paste(res(r), collapse = "x"), paste0(res_expect, " m"),
       if (res_expect == 30) "TreeMap native 30 m" else "stage one run grid 270 m (CellLength 270 in ME run script)")
  mm <- minmax(r, compute = TRUE)
  gate(st, stage, paste0(label, ":range"), mm[1] >= vmin && mm[2] <= vmax,
       paste(mm[1], mm[2]), sprintf("[%s,%s]", vmin, vmax), "physical/code bounds for this layer")
  # terra ops are chunked on disk, so this scales to 30 m state rasters
  pr  <- rasterize(poly, r, field = 1, touches = FALSE)            # 1 inside, NA outside
  okr <- ifel(!is.na(r) & (r > 0), 1, NA)                          # valid = non-NA and > 0
  n_valid <- global(okr, "sum", na.rm = TRUE)[1, 1]
  n_in    <- global(mask(okr, pr), "sum", na.rm = TRUE)[1, 1]
  fin <- if (n_valid > 0) n_in / n_valid else NA
  gate(st, stage, paste0(label, ":frac_inside_state"), !is.na(fin) && fin >= inside_min,
       sprintf("%.4f", fin), sprintf(">= %.3f", inside_min), inside_prov)
  if (!is.na(reach_min)) {
    if (reach_mode == "extent") {
      reach <- sum(expanse(crop(poly, ext(r)))) / sum(expanse(poly))
    } else {
      fp    <- ifel(!is.na(r), 1, NA)
      n_st  <- global(pr, "sum", na.rm = TRUE)[1, 1]
      n_rch <- global(mask(fp, pr), "sum", na.rm = TRUE)[1, 1]
      reach <- n_rch / n_st
    }
    gate(st, stage, paste0(label, ":frac_state_reached"), reach >= reach_min,
         sprintf("%.4f", reach), sprintf(">= %.3f", reach_min), reach_prov)
  }
  invisible(list(n_valid = n_valid, n_in = n_in, frac_inside = fin))
}
