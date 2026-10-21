#!/usr/bin/env Rscript
# s41 step H: why 3 to 17 percent of FIA 2024 forest area is absent from the
# tool. For each state, FIA forest conditions in the 2024 EXPVOL evaluation that
# no subject of the f2gate run carries, classified by the engine's own subject
# filters (01_data_prep.R: COND_STATUS_CD 1, RESERVCD 0, SITECLCD 1 to 7) and by
# measurement design. Area shares (EXPNS x CONDPROP_UNADJ) only.
suppressPackageStartupMessages(library(data.table))
W <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"; FIA <- path.expand("~/fia_data")
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27)
f <- function(st, tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
out <- list()
for (st in names(SC)) {
  sc <- SC[[st]]
  rd <- list.files(file.path(W, "engine_fix2", "output"), pattern = sprintf("^%s_[0-9]{8}_f2gate$", st), full.names = TRUE)
  d <- as.data.table(readRDS(file.path(rd, "per_plot_projections.rds")))[STATECD == sc & cycle == 1]
  tk <- unique(d[, .(loc_key = paste(as.integer(STATECD), as.integer(COUNTYCD), as.integer(PLOT), sep = "_"), CONDID = as.integer(CONDID))])
  plt <- fread(f(st,"PLOT"), select = c("CN","STATECD","COUNTYCD","PLOT","DESIGNCD"), colClasses = list(character = "CN"))
  plt[, loc_key := paste(STATECD, COUNTYCD, PLOT, sep = "_")]
  cnd <- fread(f(st,"COND"), select = c("PLT_CN","CONDID","COND_STATUS_CD","RESERVCD","SITECLCD","CONDPROP_UNADJ"), colClasses = list(character = "PLT_CN"))
  peg <- fread(f(st,"POP_EVAL_GRP"), colClasses = list(character = "CN"))
  pe  <- fread(f(st,"POP_EVAL"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
  pet <- fread(f(st,"POP_EVAL_TYP"), colClasses = list(character = c("EVAL_CN","EVAL_GRP_CN")))
  ev  <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[EVAL_GRP_CN %in% peg[EVAL_GRP == sc * 10000 + 2024, CN], .(CN, EVALID)], by.x = "EVAL_CN", by.y = "CN")
  id <- ev[EVAL_TYP == "EXPVOL", EVALID][1]
  ps <- fread(f(st,"POP_STRATUM"), colClasses = list(character = "CN"))
  ppsa <- fread(f(st,"POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"), colClasses = list(character = c("PLT_CN","STRATUM_CN")))
  w <- unique(ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS)], on = "STRATUM_CN", nomatch = NULL], by = "PLT_CN")
  x <- merge(cnd[COND_STATUS_CD == 1], w, by = "PLT_CN")
  x <- plt[, .(PLT_CN = CN, loc_key, DESIGNCD)][x, on = "PLT_CN"]
  x[, CONDID := as.integer(CONDID)]
  x[, carried := paste(loc_key, CONDID) %chin% tk[, paste(loc_key, CONDID)]]
  x[, a := EXPNS * CONDPROP_UNADJ]
  x[, reason := fifelse(carried, "carried",
                fifelse(fcoalesce(RESERVCD, 0L) != 0L, "reserved",
                fifelse(is.na(SITECLCD) | SITECLCD < 1 | SITECLCD > 7, "site class missing or invalid", "other")))]
  r <- x[, .(area_share = sum(a)), by = reason][, area_share := area_share / sum(area_share)]
  r[, state := st]
  out[[st]] <- r
}
res <- dcast(rbindlist(out), state ~ reason, value.var = "area_share", fill = 0)
fwrite(res, file.path(W, "out", "out_of_scope_area_20261016.csv"))
print(res)
cat("STEP_H_DONE\n")
