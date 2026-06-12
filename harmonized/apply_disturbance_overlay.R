#!/usr/bin/env Rscript
# apply_disturbance_overlay.R
#
# First-order disturbance/climate overlay on any anchored reserve trajectory. The
# harmonized "reserve" removes harvest AND natural disturbance, so it is a
# no-disturbance ceiling, not a likely projection - the American Forests CBM reports
# show western forests flipping to a net SOURCE under climate-driven wildfire (OR:
# high-severity fire area +825% by 2100). This overlay subtracts a stand-replacing-
# equivalent annual aboveground-carbon loss so trajectories can plateau or decline
# where fire dominates:
#
#   dB/dt = g_reserve(t) - m(t)*B(t)
#   g_reserve(t) = the no-disturbance annual increment from the input reserve
#   m(t)        = state AGC loss rate, ramped linearly 2025->2100 by ramp_2100
#
# Rates in disturbance_rates_by_state.csv are ORDER-OF-MAGNITUDE from recent MTBS-era
# burned fractions and the OR report's fire trend; they are an editable parameter,
# not a calibrated projection. Treat the output as a disturbance-aware sensitivity.
#
#   --reserve in.csv (model,dom,scenario,year,agc_TgC_anchored[,_se])  --out out.csv
#   [--rates disturbance_rates_by_state.csv]
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
RES <- ga("--reserve"); if (is.na(RES)) stop("--reserve required")
OUT <- ga("--out", sub("\\.csv$","_disturbed.csv",RES))
RATES <- ga("--rates", file.path(FIA,"disturbance_rates_by_state.csv"))
FIPS<-c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,
        ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,
        ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
fips2ab <- setNames(names(FIPS), sprintf("%02d",FIPS))
rates <- fread(RATES)

res <- fread(RES)[scenario=="reserve"]
res[, dom := sprintf("%02d", as.integer(dom))]
out <- rbindlist(lapply(split(res, res$dom), function(s){
  s <- s[order(year)]; ab <- fips2ab[s$dom[1]]
  rr <- rates[state==ab]; if (!nrow(rr)) return(s)            # no rate -> unchanged
  yr <- seq(min(s$year), max(s$year))
  B0 <- approx(s$year, s$agc_TgC_anchored, yr, rule=2)$y      # no-disturbance path
  g  <- c(0, diff(B0))                                        # annual increments
  m0 <- rr$agc_loss_rate_2025_pct_yr/100
  m  <- m0 * (1 + (rr$ramp_2100-1)*(yr-2025)/75)              # ramped loss rate
  B  <- numeric(length(yr)); B[1] <- B0[1]
  for (i in 2:length(yr)) B[i] <- max(B[i-1] + g[i] - m[i]*B[i-1], 0)
  keep <- yr %in% s$year
  data.table(model=paste0(s$model[1],"_dist"), dom=s$dom[1], scenario="reserve",
             year=yr[keep], agc_TgC_anchored=round(B[keep],3),
             agc_TgC_anchored_se=if("agc_TgC_anchored_se" %in% names(s))
               round(approx(s$year,s$agc_TgC_anchored_se,yr[keep],rule=2)$y,3) else NA_real_)
}))
fwrite(out, OUT)
cmp <- merge(res[, .(dom, year, nd=agc_TgC_anchored)], out[, .(dom, year, d=agc_TgC_anchored)], by=c("dom","year"))
g0 <- merge(cmp[year==2025,.(dom,nd0=nd,d0=d)], cmp[year==max(cmp$year),.(dom,nd1=nd,d1=d)], by="dom")
g0[, `:=`(nodist_grow=round(100*(nd1-nd0)/nd0), disturbed_grow=round(100*(d1-d0)/d0), ST=fips2ab[dom])]
cat(sprintf("disturbance overlay -> %s\n", OUT))
cat("no-disturbance vs disturbance-adjusted 2100 growth %% (fire states + east):\n")
print(g0[ST %in% c("CA","OR","WA","ID","MT","AZ","NM","MN","ME","GA","PA","OH"),
         .(ST, nodist_grow, disturbed_grow)][order(-nodist_grow)])
