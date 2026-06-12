#!/usr/bin/env python3
"""benchmark_validation.py - validate harmonized model outputs against published
American Forests state CBM reports (the external ground truth).

The American Forests "Effects of Forest Management & Wood Utilization on Carbon"
series uses CBM-CFS3 + an HWP model, the same family as our CBM, so it is a direct
benchmark for our CBM reserve/scenario behavior and a sanity bound for the others.

Checks added on top of stress_test_harmonized.py (internal consistency):
  G. CBM INITIALIZATION PLAUSIBILITY - a no-disturbance reserve that grows >100%
     over 2025-2100 implies the CBM spin-up initialized the state well below its
     FIA-observed stocking (young/under-stocked), then "regrows" into the landscape.
     Anchoring preserves that relative shape, so such states over-project. Flags the
     start per-ha density (low => under-initialized).
  H. HARVEST-RATE SANITY - a known timber state with a near-zero HCS harvest rate
     collapses its scenario spread (reserve ~= BAU ~= intensive). Flags states whose
     harvest_rate_pct_yr is implausibly low and whose reserve-vs-intensive 2100
     spread is < 2%.
  I. BENCHMARK DIRECTION - compares our no-disturbance reserve trend against the
     published BAU/CBAU trend. Western fire-dominated states (OR, CA) where the
     report shows the forest flipping to a net SOURCE are EXPECTED to diverge from
     our reserve (which omits disturbance + climate productivity decline by design);
     this is reported as an interpretation caveat, not a code failure.
"""
import csv, os, sys

FIA="/fs/scratch/PUOM0008/crsfaaron/FIA"
HCS="/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv"
BENCH=os.path.join(os.path.dirname(os.path.abspath(__file__)),"americanforests_cbm_benchmarks.csv")
if not os.path.exists(BENCH): BENCH=f"{FIA}/americanforests_cbm_benchmarks.csv"

fips2ab={1:"AL",4:"AZ",5:"AR",6:"CA",8:"CO",9:"CT",10:"DE",12:"FL",13:"GA",16:"ID",17:"IL",18:"IN",
 19:"IA",20:"KS",21:"KY",22:"LA",23:"ME",24:"MD",25:"MA",26:"MI",27:"MN",28:"MS",29:"MO",30:"MT",
 31:"NE",32:"NV",33:"NH",34:"NJ",35:"NM",36:"NY",37:"NC",38:"ND",39:"OH",40:"OK",41:"OR",42:"PA",
 44:"RI",45:"SC",46:"SD",47:"TN",48:"TX",49:"UT",50:"VT",51:"VA",53:"WA",54:"WV",55:"WI",56:"WY"}

bench={r["state"]:r for r in csv.DictReader(open(BENCH))}
hcs={r["state"]:r for r in csv.DictReader(open(HCS))}

# CBM reserve trajectory -> 2025 + 2100 by state
res={}
for r in csv.DictReader(open(f"{FIA}/cbm_reserve_anchored.csv")):
    ab=fips2ab.get(int(r["dom"])); y=int(float(r["year"])); v=float(r["agc_TgC_anchored"])
    res.setdefault(ab,{})[y]=v
# CBM 4-scenario 2100 totals
summ={}
for r in csv.DictReader(open(f"{FIA}/harmonized_carbon_npv_CBM.csv")):
    summ.setdefault(r["state"],{})[r["scenario"]]=float(r["total_2100_TgC"])

warns=[]; notes=[]
print("="*72); print("G. CBM INITIALIZATION PLAUSIBILITY (no-disturbance reserve growth)"); print("="*72)
print(f"  {'ST':3} {'2025':>9} {'2100':>9} {'growth%':>8}   flag")
for ab in sorted(res):
    ys=res[ab];
    if 2025 not in ys or 2100 not in ys: continue
    g=100*(ys[2100]-ys[2025])/ys[2025]
    flag=""
    if g>100: flag="UNDER-INITIALIZED? (>100% regrowth)"; warns.append(f"CBM {ab} reserve grows {g:.0f}% (under-stocked spin-up)")
    elif g>75: flag="high growth, check IC"
    print(f"  {ab:3} {ys[2025]:9.1f} {ys[2100]:9.1f} {g:8.0f}   {flag}")

print("\n"+"="*72); print("H. HARVEST-RATE SANITY (HCS rate vs scenario spread)"); print("="*72)
TIMBER={"OR","WA","CA","ME","MN","WI","MI","AL","GA","MS","AR","LA","NC","SC","VA","PA"}  # major harvest states
print(f"  {'ST':3} {'rate%/yr':>9} {'clrcut_ha':>10} {'spread%':>8}   flag")
for ab in sorted(summ):
    if ab not in hcs: continue
    rate=float(hcs[ab]["harvest_rate_pct_yr"]); cc=float(hcs[ab]["clearcut_ha_yr"])
    sc=summ[ab]
    if "reserve" in sc and "intensive" in sc and sc["reserve"]>0:
        spread=100*(sc["reserve"]-sc["intensive"])/sc["reserve"]
    else: spread=float("nan")
    flag=""
    if ab in TIMBER and rate<0.02:
        flag="HARVEST TOO LOW for a timber state -> scenarios collapse"
        warns.append(f"HCS {ab} rate {rate:.3f}%/yr implausibly low (timber state); scenario spread {spread:.1f}%")
    print(f"  {ab:3} {rate:9.3f} {cc:10.0f} {spread:8.1f}   {flag}")

print("\n"+"="*72); print("I. BENCHMARK DIRECTION (our reserve vs published BAU/CBAU)"); print("="*72)
for ab in sorted(bench):
    b=bench[ab]; ys=res.get(ab,{})
    if 2025 in ys and 2100 in ys:
        g=100*(ys[2100]-ys[2025])/ys[2025]; ours="grows %+.0f%%"%g
    else: ours="(no CBM)"
    print(f"  {ab}: published BAU trend = {b['bau_trend']:24} ; our no-disturbance reserve {ours}")
    print(f"       published headline: {b['headline_metric']} = {b['headline_value_pct']}% (by {b['horizon_end']}, {b['model']})")
    if b["bau_trend"] in ("flips_to_source_2029","declining") and "grows" in ours:
        notes.append(f"{ab}: report shows climate/fire-driven DECLINE; our reserve grows because it omits disturbance+climate productivity loss (reserve = no-disturbance ceiling, not a likely projection)")

print("\n"+"="*72)
print(f"RESULT: {len(warns)} refinement flags, {len(notes)} interpretation caveats")
for w in warns: print("  FLAG:", w)
for n in notes: print("  CAVEAT:", n)
print("="*72)
