suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data"); f <- function(s,t) file.path(FIA, sprintf("%s_%s.csv", s, t))
for (st in c("NH","ME","MN")) {
  sc <- c(NH=33,ME=23,MN=27)[[st]]; eid <- sc*10000 + 2401
  ppsa <- fread(f(st,"POP_PLOT_STRATUM_ASSGN"), select=c("PLT_CN","STRATUM_CN","EVALID"), colClasses=list(character=c("PLT_CN","STRATUM_CN")))[EVALID==eid]
  ps <- fread(f(st,"POP_STRATUM"), select=c("CN","EXPNS","ADJ_FACTOR_SUBP","ADJ_FACTOR_MICR","ADJ_FACTOR_MACR"), colClasses=list(character="CN"))
  w <- ps[ppsa, on=c(CN="STRATUM_CN")]
  cnd <- fread(f(st,"COND"), select=c("PLT_CN","CONDID","COND_STATUS_CD"), colClasses=list(character="PLT_CN"))[COND_STATUS_CD==1]
  tr <- fread(f(st,"TREE"), select=c("PLT_CN","CONDID","STATUSCD","DIA","TPA_UNADJ","DRYBIO_AG"), colClasses=list(character="PLT_CN"))[STATUSCD==1 & !is.na(DIA) & DIA>=1]
  tr <- tr[cnd[,.(PLT_CN,CONDID)], on=c("PLT_CN","CONDID"), nomatch=NULL]
  pl <- fread(f(st,"PLOT"), select=c("CN","MACRO_BREAKPOINT_DIA"), colClasses=list(character="CN"))
  tr <- pl[tr, on=c(CN="PLT_CN")]; tr <- w[tr, on=c(PLT_CN="CN"), nomatch=NULL]
  tr[, adj := fifelse(DIA < 5, ADJ_FACTOR_MICR, fifelse(!is.na(MACRO_BREAKPOINT_DIA) & DIA >= MACRO_BREAKPOINT_DIA, ADJ_FACTOR_MACR, ADJ_FACTOR_SUBP))]
  cat(st, eid, "independent live AG stock Tg:", sprintf("%.4f", tr[, sum(TPA_UNADJ*DRYBIO_AG*adj*EXPNS, na.rm=TRUE)]*4.53592e-10), "\n")
}
