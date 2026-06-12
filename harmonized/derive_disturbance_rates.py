#!/usr/bin/env python3
# derive_disturbance_rates.py - per-state natural-disturbance mortality rate from the
# CBM no-disturbance (BAU) vs LCMS natural-only (lcms_nat_HIST) runs. lcms_nat applies
# the OBSERVED LCMS natural disturbance regime (fire/insect/wind, harvest excluded),
# so the AG-live gap vs BAU over the simulated window is the real, pipeline-consistent
# disturbance carbon loss. Implied constant annual loss rate m solves the endpoint gap:
#   gap = m * mean(B) * nyears  ->  m = gap / (mean(B)*nyears)
# This is the HISTORICAL base rate (no climate ramp); the ramp is added separately.
import csv, os, glob
P="/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm"
AG=["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
FIPS={1:"AL",4:"AZ",5:"AR",6:"CA",8:"CO",9:"CT",10:"DE",12:"FL",13:"GA",16:"ID",17:"IL",18:"IN",
 19:"IA",20:"KS",21:"KY",22:"LA",23:"ME",24:"MD",25:"MA",26:"MI",27:"MN",28:"MS",29:"MO",30:"MT",
 31:"NE",32:"NV",33:"NH",34:"NJ",35:"NM",36:"NY",37:"NC",38:"ND",39:"OH",40:"OK",41:"OR",42:"PA",
 44:"RI",45:"SC",46:"SD",47:"TN",48:"TX",49:"UT",50:"VT",51:"VA",53:"WA",54:"WV",55:"WI",56:"WY"}
def ser(fn):
    d={}
    for r in csv.DictReader(open(fn)):
        try: d[int(float(r["timestep"]))]=sum(float(r[c]) for c in AG if c in r)/1e6
        except: pass
    return d
rows=[]
for fp,ab in FIPS.items():
    bau=f"{P}/{ab}/conus_dist/pools_{ab}_BAU.csv"
    nat=f"{P}/{ab}/conus_dist/pools_{ab}_lcms_nat_HIST.csv"
    if not (os.path.exists(bau) and os.path.exists(nat)): continue
    b=ser(bau); n=ser(nat)
    tmax=max(set(b)&set(n));
    if tmax<5: continue
    gap=b[tmax]-n[tmax]
    Bavg=sum(n[t] for t in n if t<=tmax)/len([t for t in n if t<=tmax])
    m=max(gap/(Bavg*tmax),0.0)              # annual fractional AG-C loss rate
    rows.append((ab, round(100*m,4), round(b[0],1), tmax))
rows.sort(key=lambda x:-x[1])
print("%-3s %10s %9s %5s"%("ST","m_pct_yr","B0_TgC","nyr"))
for ab,m,b0,ny in rows: print("%-3s %10.4f %9.1f %5d"%(ab,m,b0,ny))
with open("/fs/scratch/PUOM0008/crsfaaron/FIA/disturbance_rates_data.csv","w",newline="") as o:
    w=csv.writer(o); w.writerow(["state","agc_loss_rate_2025_pct_yr_LCMS"])
    for ab,m,_,_ in rows: w.writerow([ab,m])
print(f"\nwrote {len(rows)} states -> disturbance_rates_data.csv")
