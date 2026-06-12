#!/usr/bin/env Rscript
# build_cbm_reserve.R
#
# CBM (libcbm/GCBM) reserve trajectory on the common pipeline (5th model). The
# CBM "bau" run uses an empty disturbance-events file (no harvest, no disturbance)
# = the reserve. This reads each state's gcbm_state_aggregate.csv, takes the
# aboveground biomass carbon (variable=AG_Biomass_C, total_TgC by step), maps step
# -> year, and anchors year-0 to the FIA design total - same anchor as every model.
# AG_Biomass_C is used (NOT Total_Ecosystem_C, which includes large soil/DOM pools
# not comparable to the other models' live AGC).
#
#   --cbm   cbm_states/states dir   --out   output csv
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
# Full-CONUS source: cross_state/libcbm/<ST>/conus_dist/pools_<ST>_BAU.csv (76 steps -> 2100,
# all 48 states). Aboveground live C = the 6 SW/HW Merch+Foliage+Other pools (no roots/soil/snag).
POOLS <- ga("--pools","/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm")
CBM <- ga("--cbm","/users/PUOM0008/crsfaaron/cbm_states/states")   # legacy gcbm fallback
OUT <- ga("--out", file.path(FIA,"cbm_reserve_anchored.csv"))
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
          LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
          NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
          VA=51,WA=53,WV=54,WI=55,WY=56)
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]

AG_POOLS <- c("SoftwoodMerch","SoftwoodFoliage","SoftwoodOther",
              "HardwoodMerch","HardwoodFoliage","HardwoodOther")
# --align TRUE applies the entry-point correction (default): the CBM conus_dist
# spin-up under-initializes many eastern states (FIA stocking 1.5-2.7x the spin-up
# t0), so the raw no-disturbance reserve "regrows" 150-200% by 2100, which the
# anchoring then preserves. The correction fits CBM's own asymptotic growth form
# (monomolecular SSasymp) to the AG series, locates the stand age t* where the
# fitted curve equals the FIA-observed stocking, and follows CBM's curve forward
# from t* (entering at the mature stocking FIA actually measures). This keeps CBM's
# carrying capacity and growth rate but removes the spurious early-regrowth ramp,
# and extrapolates smoothly to 2100 (no truncation). Interim pending a true
# FIA-initialized CBM re-run. ratio<=1.05 (well/over-initialized, mostly western)
# keeps the simple ratio-anchor. Writes BOTH files so the effect is auditable.
ALIGN <- toupper(ga("--align","TRUE")) %in% c("TRUE","T","1","YES")
OUT_RAW <- ga("--out_raw", file.path(FIA,"cbm_reserve_raw_anchored.csv"))

read_series <- function(st){
  pf <- file.path(POOLS, st, "conus_dist", sprintf("pools_%s_BAU.csv", st))
  if (file.exists(pf)) {
    d <- fread(pf); if (!all(c("timestep", AG_POOLS) %in% names(d))) return(NULL)
    d[, agb := rowSums(.SD)/1e6, .SDcols=AG_POOLS]   # tonnes C -> Tg C (match FIA anchor units)
    return(d[, .(t = as.integer(timestep), year = 2024 + as.integer(timestep), agb)][order(t)])
  }
  f <- file.path(CBM, st, "10_outputs", "gcbm_state_aggregate.csv")
  if (!file.exists(f)) return(NULL)
  d <- fread(f); if (!all(c("variable","step","total_TgC") %in% names(d))) return(NULL)
  d[variable=="AG_Biomass_C", .(t=as.integer(step), year=2024+as.integer(step), agb=total_TgC)][order(t)]
}

build <- function(aligned){
 rbindlist(lapply(names(FIPS), function(st){
  s <- read_series(st); if (is.null(s) || nrow(s) < 3) return(NULL)
  a <- anc[state==st]; if (!nrow(a)) return(NULL)
  fia <- a$fia; t0 <- s$agb[s$t==min(s$t)]; if (is.na(t0) || t0<=0) return(NULL)
  ratio <- fia / t0
  yr <- 2025:2100
  if (!aligned || ratio <= 1.05) {
    # ratio-anchor on the raw curve (legacy / well-initialized states)
    sr <- s[year >= 2025 & year <= 2100]; if (!(2025 %in% sr$year)) return(NULL)
    c0 <- sr$agb[sr$year==2025]; if (c0<=0) return(NULL)
    perha <- approx(sr$year, sr$agb, yr, rule=2)$y
    agc <- fia * perha / perha[1]
  } else {
    # Estimate CBM's own carrying capacity (Asym) and growth rate (k) by regressing
    # the annual AG increment on AG size: monomolecular dAG/dt = k*(Asym - AG), so
    # dAG = k*Asym - k*AG (a plain lm, always converges). Then project FORWARD from
    # the FIA-observed stocking using CBM's own (k, Asym):
    #   AG(tau) = Asym - (Asym - fia)*exp(-k*tau),  tau = year - 2025.
    # This enters CBM's curve at the mature stocking FIA measures and removes the
    # spurious early-regrowth ramp produced by the under-stocked spin-up.
    so <- s[order(t)]
    dAG <- diff(so$agb)/diff(so$t); AGm <- head(so$agb,-1)
    fitc <- tryCatch(coef(lm(dAG ~ AGm)), error=function(e) NULL)
    k    <- if (is.null(fitc)) NA else -as.numeric(fitc["AGm"])
    Asym <- if (is.null(fitc) || k<=0) NA else as.numeric(fitc["(Intercept)"]) / k
    if (is.na(k) || k<=0 || is.na(Asym) || Asym <= fia) {
      # CBM has no usable deceleration, or FIA already at/above CBM carrying capacity
      # (mature forest) -> hold ~flat at the FIA stocking (no spurious regrowth)
      agc <- rep(fia, length(yr))
    } else {
      tau <- yr - 2025
      agc <- as.numeric(Asym - (Asym - fia)*exp(-k*tau)); agc[1] <- fia
    }
  }
  data.table(model="CBM", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=yr, agc_TgC_anchored=round(agc,3),
             agc_TgC_anchored_se=round(agc*a$cv/100,3))
 }))
}

raw <- build(FALSE); fwrite(raw, OUT_RAW)
out <- if (ALIGN) build(TRUE) else raw
fwrite(out, OUT)
cat(sprintf("CBM reserve [%s]: %d states -> %s\n", if(ALIGN)"entry-point aligned" else "raw ratio-anchor",
            uniqueN(out$dom), OUT))
cat(sprintf("raw ratio-anchor copy -> %s\n", OUT_RAW))
cmp <- merge(raw[year %in% c(2025,2100), .(dom, year, raw=agc_TgC_anchored)],
             out[year %in% c(2025,2100), .(dom, year, adj=agc_TgC_anchored)], by=c("dom","year"))
g <- merge(cmp[year==2025,.(dom,raw0=raw,adj0=adj)], cmp[year==2100,.(dom,raw1=raw,adj1=adj)], by="dom")
g[, `:=`(raw_grow=round(100*(raw1-raw0)/raw0), adj_grow=round(100*(adj1-adj0)/adj0))]
cat("\n2100 growth %: raw vs entry-point-aligned (first 12 states)\n")
print(g[order(dom), .(dom, raw_grow, adj_grow)][1:12])
