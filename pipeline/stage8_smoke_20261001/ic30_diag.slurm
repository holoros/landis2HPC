#!/bin/bash
#SBATCH --job-name=ic30_diag --account=PUOM0008 --time=00:45:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=96G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/ic30_diag_%j.out
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
Rscript -e '
suppressMessages({library(terra); library(data.table)})
D<-"/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
out<-list()
for(st in c("NH","VT","MI","WI")){
 IN<-file.path(D,st,"inputs"); R<-file.path(D,st,"runs/smoke_20261001_d10")
 ic<-rast(file.path(IN,"initial_communities/initial-communities.tif")); e<-rast(file.path(IN,"ecoregions_20260929.tif"))
 cb<-fread(file.path(IN,"initial_communities/cohort_biomass_by_mapcode.csv"))[,.(g=sum(CohortBiomass)),by=MapCode]
 icm<-mask(ic, e)  # in-state, ecoregion-bearing 30 m cells only
 fr<-as.data.table(freq(icm)); setnames(fr,c("layer","MapCode","n")); fr<-fr[MapCode>0]
 v<-merge(fr,cb,by="MapCode",all.x=TRUE); nomatch<-v[is.na(g),sum(n)]; v[is.na(g),g:=0]
 tg30<-v[,sum(n*900*g)]/1e12; ha30<-v[,sum(n)]*900/1e4
 bs<-fread(file.path(R,"build_summary.csv"))
 out[[st]]<-data.table(state=st, ic30_forest_ha=round(ha30), ic30_Tg=round(tg30,2), ic30_Mg_ha=round(tg30*1e6/ha30,1),
   ic30_cells_mapcode_unmatched=nomatch, smoke270_active_ha=bs$active_ha, smoke270_Tg=bs$ic_implied_year0_Tg,
   area_ratio_270_to_30=round(bs$active_ha/ha30,4), tg_ratio_270_to_30=round(bs$ic_implied_year0_Tg/tg30,4))
 print(out[[st]])
}
fwrite(rbindlist(out), file.path(D,"gates/ic30_vs_smoke270_20261001.csv"))
'

