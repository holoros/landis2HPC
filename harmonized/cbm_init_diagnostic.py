#!/usr/bin/env python3
# cbm_init_diagnostic.py - compare CBM spin-up t0 aboveground live C per ha against
# the FIA design stocking per ha, by state. A ratio >> 1 means CBM initialized the
# state below FIA-observed stocking, so its no-disturbance reserve "regrows" and the
# anchored trajectory over-projects.
import csv, os
P="/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm"
HCS=P+"/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv"
FIA="/fs/scratch/PUOM0008/crsfaaron/FIA"
anc={r["state"]:float(r["agc_TgC_design"]) for r in csv.DictReader(open(FIA+"/fia_agc_anchor_design_by_state.csv"))}
fha={r["state"]:float(r["forest_ha"]) for r in csv.DictReader(open(HCS))}
AG=["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
rows=[]
for st in anc:
    f="%s/%s/conus_dist/pools_%s_BAU.csv"%(P,st,st)
    if not os.path.exists(f) or st not in fha: continue
    r0=next(csv.DictReader(open(f)))
    cbm_t0=sum(float(r0[c]) for c in AG)/1e6
    if cbm_t0<=0: continue
    fia=anc[st]; ratio=fia/cbm_t0
    rows.append((st, fia*1e6/fha[st], cbm_t0*1e6/fha[st], ratio))
rows.sort(key=lambda x:-x[3])
print("%-3s %9s %9s %7s"%("ST","FIA_perha","CBM_t0_ph","FIA/CBM"))
und=0
for st,fp,cp,r in rows:
    flag=" <-- under-initialized" if r>1.5 else ""
    und += r>1.5
    print("%-3s %9.1f %9.1f %7.2f%s"%(st,fp,cp,r,flag))
vals=sorted(x[3] for x in rows)
med=vals[len(vals)//2]
print("\n%d/%d states have FIA stocking > 1.5x CBM spin-up t0 (under-initialized)"%(und,len(rows)))
print("median FIA/CBM t0 ratio: %.2f"%med)
