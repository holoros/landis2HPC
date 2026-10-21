suppressPackageStartupMessages(library(data.table))
W <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
for (st in c("ME","NH","VT","MI","WI","MN")) {
  rd <- list.files(file.path(W,"engine","output"), pattern=sprintf("^%s_[0-9]{8}_s41gate$",st), full.names=TRUE)
  d <- as.data.table(readRDS(file.path(rd,"per_plot_projections.rds")))
  c1 <- d[cycle==1 & scenario=="BAU"]
  cat(st, "rows/sim c1:", paste(range(c1[,.N,by=sim]$N),collapse="-"),
      " distinct subj keys all sims:", uniqueN(c1[, paste(STATECD,COUNTYCD,PLOT,CONDID)]), "\n")
  print(c1[sim==1, .N, by=.(it=cem_iteration)][order(it)])
  cat(" max dup key within sim:", max(c1[, .N, by=.(sim,STATECD,COUNTYCD,PLOT,CONDID)]$N), "\n")
  print(merge(c1[sim==1,.(sim1=.N),by=STATECD], c1[,.(distinct=uniqueN(paste(COUNTYCD,PLOT,CONDID))),by=STATECD], by="STATECD")[, share:=round(sim1/distinct,3)][])
  if ("CONDPROP_UNADJ" %in% names(d)) cat(" CONDPROP_UNADJ mean", mean(c1$CONDPROP_UNADJ,na.rm=TRUE), "\n")
  bc <- grep("per_acre", names(d), value=TRUE); cat(" cols:", bc, "\n")
  if (all(c("biomass_lb_per_acre","pre_drybio_ag") %in% names(d))) cat(" biomass_lb_per_acre/pre median", median(c1$biomass_lb_per_acre/c1$pre_drybio_ag, na.rm=TRUE), "\n")
}
