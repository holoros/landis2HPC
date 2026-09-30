source("~/landis2_fb/scripts_20260929/gates_lib.R")
for (ST in c("NH","VT","MI","WI")) {
  IN <- file.path(FB, "states", ST, "inputs")
  f <- fread(file.path(IN, "SppEcoregionData_fia_20260929.csv")); d <- fread(file.path(IN, "SppEcoregionData.csv"))
  txt <- readLines(file.path(IN, "ecoregions_20260929.txt")); tc <- sub("^yes\t([0-9]+)\t.*", "\\1", grep("^yes", txt, value = TRUE))
  gate(ST, "stage7", "fia_table:rows_equal_dryad", nrow(f) == nrow(d), sprintf("%d vs %d", nrow(f), nrow(d)), "equal", "Dryad SppEcoregionData.csv row count")
  gate(ST, "stage7", "fia_table:species_set_equals_dryad", setequal(f$SpeciesCode, d$SpeciesCode), paste(sort(unique(f$SpeciesCode)), collapse = " "), "same set", "Dryad SpeciesCode set")
  gate(ST, "stage7", "fia_table:no_coordinate_or_cn_column", !any(grepl("LAT|LON|PLT_CN|CN$", names(f))), paste(names(f), collapse = " "), "none", "FIA privacy")
  gate(ST, "stage7", "fia_table:BiomassMax_bound", all(f$BiomassMax >= 1000 & f$BiomassMax <= 60000), sprintf("%d..%d", min(f$BiomassMax), max(f$BiomassMax)), "1000..60000 g m-2", "session 29 bound")
  ex <- setdiff(unique(as.character(f$EcoregionName)), tc)
  gate(ST, "stage7", "fia_table:ecoregions_not_in_raster", length(ex) == 0, if (length(ex)) paste(ex, collapse = " ") else "none", "none", "rows for ecoregion codes the state raster lacks are Dryad inheritance (Maine code 82) and are inert in LANDIS, which reads ecoregions.txt; flagged for Aaron")
  src <- if ("source" %in% names(f)) table(f$source) else NA; cat(ST, "source:", paste(names(src), src, collapse = ", "), "\n")
}
