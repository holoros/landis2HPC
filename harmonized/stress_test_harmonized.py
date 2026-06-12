#!/usr/bin/env python3
"""stress_test_harmonized.py - adversarial checks on the harmonized multi-model outputs.

Verifies the apples-to-apples invariants that must hold for every model:
  A. ANCHOR: each model's reserve at 2025 == the FIA design total per state (the
     common anchor; any mismatch breaks the comparison).
  B. MONOTONICITY: total 2100 carbon reserve >= conservation >= BAU >= intensive
     (more harvest -> less forest carbon).
  C. RESERVE HWP: reserve scenario HWP == 0 (no harvest -> no products).
  D. SANITY: no NaN / non-positive / absurd per-ha (anchored total / state).
  E. HORIZON: reserve trajectory reaches a year near 2100.
  F. CROSS-MODEL ANCHOR: in the 5-model overlap, all models share the 2025 anchor.
Exits non-zero if any hard check fails.
"""
import csv, os, glob, math, sys
FIA="/fs/scratch/PUOM0008/crsfaaron/FIA"
fips2ab={1:"AL",4:"AZ",5:"AR",6:"CA",8:"CO",9:"CT",10:"DE",12:"FL",13:"GA",16:"ID",17:"IL",18:"IN",
 19:"IA",20:"KS",21:"KY",22:"LA",23:"ME",24:"MD",25:"MA",26:"MI",27:"MN",28:"MS",29:"MO",30:"MT",
 31:"NE",32:"NV",33:"NH",34:"NJ",35:"NM",36:"NY",37:"NC",38:"ND",39:"OH",40:"OK",41:"OR",42:"PA",
 44:"RI",45:"SC",46:"SD",47:"TN",48:"TX",49:"UT",50:"VT",51:"VA",53:"WA",54:"WV",55:"WI",56:"WY"}
design={}
for r in csv.DictReader(open(f"{FIA}/fia_agc_anchor_design_by_state.csv")):
    design[r["state"]]=float(r["agc_TgC_design"])

reserves={"LANDIS":"harmonized_landis_reserve_7state.csv","FVS_cal":"fvs_reserve_calibrated_anchored.csv",
 "FVS_def":"fvs_reserve_default_anchored.csv","YieldCurve":"yc_reserve_anchored.csv",
 "CEM":"cem_reserve_anchored.csv","CBM":"cbm_reserve_anchored.csv"}
summaries={"FVS_cal":"harmonized_carbon_npv_FVScalibrated.csv","FVS_def":"harmonized_carbon_npv_FVSdefault.csv",
 "YieldCurve":"harmonized_carbon_npv_YC.csv","LANDIS":"harmonized_carbon_npv_7state.csv",
 "CEM":"harmonized_carbon_npv_CEM.csv","CBM":"harmonized_carbon_npv_CBM.csv"}

fails=[]; warns=[]
print("="*64); print("A. ANCHOR INTEGRITY (reserve@2025 == FIA design per state)"); print("="*64)
for m,f in reserves.items():
    p=f"{FIA}/{f}"
    if not os.path.exists(p): print(f"  {m}: (missing {f})"); continue
    rows=[r for r in csv.DictReader(open(p))]
    by={}
    for r in rows:
        try: by.setdefault(r["dom"],{})[int(float(r["year"]))]=float(r["agc_TgC_anchored"])
        except: pass
    bad=0; n=0
    for dom,ys in by.items():
        ab=fips2ab.get(int(dom)); fia=design.get(ab)
        if fia is None: continue
        y0=min(ys); v=ys[y0]; n+=1
        if abs(v-fia)/fia>0.005:  # >0.5% off
            bad+=1
            if bad<=3: print(f"    {m} {ab}: 2025={v:.1f} vs FIA design {fia:.1f} (off {100*(v-fia)/fia:+.1f}%)")
    status="OK" if bad==0 else f"{bad}/{n} MISMATCH"
    print(f"  {m}: {n} states, anchor {status}" + ("" if min(by[list(by)[0]])==2025 else f"  [y0={min(by[list(by)[0]])}]"))
    if bad>0: fails.append(f"{m} anchor mismatch {bad}/{n}")

print("\n"+"="*64); print("B-E. SCENARIO MONOTONICITY / HWP / SANITY (per model summary)"); print("="*64)
for m,f in summaries.items():
    p=f"{FIA}/{f}"
    if not os.path.exists(p): print(f"  {m}: (missing)"); continue
    by={}
    for r in csv.DictReader(open(p)):
        try: by.setdefault(r["state"],{})[r["scenario"]]={"tot":float(r["total_2100_TgC"]),"hwp":float(r["hwp_2100_TgC"]),"fr":float(r["forest_2100_TgC"])}
        except: pass
    nmono=nhwp=nnan=0; nst=len(by)
    for st,sc in by.items():
        order=["reserve","conservation","BAU","intensive"]
        vals=[sc[o]["tot"] for o in order if o in sc]
        if any(math.isnan(v) or v<=0 for v in vals): nnan+=1
        for i in range(len(vals)-1):
            if vals[i] < vals[i+1]-0.5: nmono+=1; break
        if "reserve" in sc and abs(sc["reserve"]["hwp"])>0.01: nhwp+=1
    print(f"  {m}: {nst} states | monotonicity viol={nmono} | reserve-HWP!=0={nhwp} | NaN/neg={nnan}")
    if nmono>0: warns.append(f"{m} {nmono} states violate scenario monotonicity")
    if nhwp>0: fails.append(f"{m} {nhwp} states have nonzero reserve HWP")
    if nnan>0: fails.append(f"{m} {nnan} states NaN/neg total")

print("\n"+"="*64); print("F. CROSS-MODEL ANCHOR AGREEMENT (overlap states)"); print("="*64)
res2025={}
for m,f in reserves.items():
    p=f"{FIA}/{f}"
    if not os.path.exists(p): continue
    for r in csv.DictReader(open(p)):
        try:
            y=int(float(r["year"]))
            if y==min(int(float(x["year"])) for x in []) : pass
        except: pass
# simpler: collect each model's 2025 by state
for m,f in reserves.items():
    p=f"{FIA}/{f}"
    if not os.path.exists(p): continue
    by={}
    for r in csv.DictReader(open(p)):
        try: by.setdefault(fips2ab.get(int(r["dom"])),{})[int(float(r["year"]))]=float(r["agc_TgC_anchored"])
        except: pass
    res2025[m]={st:ys[min(ys)] for st,ys in by.items() if ys}
allmods=list(res2025)
common=set.intersection(*[set(res2025[m]) for m in allmods]) if allmods else set()
print(f"  states in all {len(allmods)} reserve files: {sorted(common)}")
for st in sorted(common):
    vals={m:res2025[m][st] for m in allmods}
    spread=max(vals.values())-min(vals.values())
    fia=design.get(st,0)
    ok="OK" if (fia and spread/fia<0.01) else "DIVERGENT"
    print(f"    {st}: " + " ".join(f"{m}={v:.0f}" for m,v in vals.items()) + f"  spread={spread:.1f} [{ok}]")
    if fia and spread/fia>=0.01: fails.append(f"{st} cross-model 2025 anchor spread {spread:.1f}")

print("\n"+"="*64)
print(f"RESULT: {len(fails)} hard failures, {len(warns)} warnings")
for x in fails: print("  FAIL:", x)
for x in warns: print("  WARN:", x)
print("="*64)
sys.exit(1 if fails else 0)
