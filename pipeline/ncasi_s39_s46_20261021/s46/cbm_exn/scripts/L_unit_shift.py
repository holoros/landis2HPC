"""s46 Track L step 2: unit stand checks of the registered spinup table (plan v6 L2, v9 L4, v10 item 4).
Per state, two stands (sw: SF curve, hw: MBB curve; statewide ALL AGB_mean, Mg/ha dry) with FIXED synthetic
component shares (merch 0.6, other 0.4, foliage 0.05 of AGB; unit check only, not the NSVB split).
Inventory ages 1, 2, 20, q99+10 (FIA extrapolated age), K = 250, K+5 = 255. Spinup with J = spinup_table(I, s) for
s = 0 (pre-shift evidence) and s = 1 (registered); then one stepping year supplying I(a+1). CF 0.5 in and out.
usage: python L_unit_shift.py ST OUTDIR"""
import os, sys, json, sqlite3
import numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
import exn_common as E, trackL_common as TC
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm_exn import cbm_exn_model
from libcbm.model.cbm_exn.cbm_exn_parameters import parameters_factory
ST, OUT = sys.argv[1], sys.argv[2]; os.makedirs(OUT, exist_ok=True)
S45 = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn"
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
W = os.path.join(S45, "out", "L2", ST, "work_copy")
CUR = {"ME": "/users/PUOM0008/crsfaaron/maine_agb_yc_20261015/zenodo_upload/data/final_curves_capped_DATA.csv"}
for s in ("NH", "VT"): CUR[s] = f"/users/PUOM0008/crsfaaron/nhvt_agb_yc_20261016/out/stress/final_curves_capped_{s}_DATA.csv"
for s in ("MI", "WI", "MN"): CUR[s] = f"/users/PUOM0008/crsfaaron/lakes_agb_yc_20261016/yc_lakes_deliver/curves/final_curves_capped_{s}_DATA.csv"
S = E.spin_settings(ST); spu = S["spatial_unit_id"]
sit = sit_cbm_factory.load_sit(os.path.join(W, "sit_config.json"), db_path=DB); dmap = sit.default_disturbance_id_map
s0 = pd.read_csv(os.path.join(S45, "out", "L2", ST, f"cap_snapshots_{ST}.csv")); s0 = s0[s0.t == 0].sort_values("row").iloc[0]
hist = dmap[int(s0.inv_historical_disturbance_type)]; lastp = dmap[int(s0.inv_last_pass_disturbance_type)]
PX = parameters_factory(E.exn_dir(ST), None); swmap = PX.get_sw_hw_map()
spc = {0: int([k for k, x in swmap.items() if x == 0][0]), 1: int([k for k, x in swmap.items() if x == 1][0])}
cv = pd.read_csv(CUR[ST]); cv = cv[cv.section == "ALL"]
SH = np.array([0.6, 0.05, 0.4])  # merch, foliage, other (fraction of AGB)
stands = []; Bc = {}
for code, g in ((0, "SF"), (1, "MBB")):
    c = cv[cv.ftg == g].sort_values("age"); assert (c.age.values == np.arange(0, 251)).all()
    B = np.outer(c.AGB_mean.values, SH) * E.CF          # ages 0..250, C, (merch, foliage, other)
    Bc[code] = B; q99 = int(round(c.age_q99.iloc[0]))
    for a in (1, 2, 20, q99 + 10, 250, 255): stands.append((code, g, a))
K = 250
def Bat(code, a): return Bc[code][min(a, K)]           # continuation: held at B(K) beyond K
def Iat(code, a): return Bc[code][a] - Bc[code][a - 1] if 1 <= a <= K else np.zeros(3)
rows = []
for shift in (0, 1):
    par = pd.DataFrame({"age": [a for _, _, a in stands], "area": 1.0, "delay": 0, "return_interval": S["return_interval"],
                        "min_rotations": S["min_rotations"], "max_rotations": S["max_rotations"], "spatial_unit_id": spu,
                        "species": [spc[c] for c, _, _ in stands], "sw_hw": [c for c, _, _ in stands],
                        "mean_annual_temperature": S["historic_mean_temperature"], "historical_disturbance_type": hist,
                        "last_pass_disturbance_type": lastp})
    inc = []
    for i, (code, g, a) in enumerate(stands):
        I = np.diff(Bc[code], axis=0); J = TC.spinup_table(I, shift)
        inc.append(pd.DataFrame({"row_idx": i, "age": np.arange(1, K + 1), "merch_inc": J[:, 0], "foliage_inc": J[:, 1], "other_inc": J[:, 2]}))
    inc = pd.concat(inc, ignore_index=True)
    with cbm_exn_model.initialize(config_path=E.exn_dir(ST)) as m:
        v = m.spinup({"parameters": par, "increments": inc})
        for k in list(v.keys()): v[k] = v[k].reset_index(drop=True)
        P0 = v["pools"][["Merch", "Foliage", "Other"]].values.copy(); age0 = v["state"]["age"].values.copy()
        v["parameters"]["mean_annual_temperature"] = S["mean_annual_temperature"]
        Is = np.array([Iat(c, a + 1) for c, _, a in stands])
        v = E.step(m, v, Is[:, 0], Is[:, 1], Is[:, 2], np.zeros(len(stands), dtype=int))
        P1 = v["pools"][["Merch", "Foliage", "Other"]].values.copy(); age1 = v["state"]["age"].values.copy()
    for i, (code, g, a) in enumerate(stands):
        for lab, P, ag, tgt in (("end_spinup", P0[i], age0[i], a), ("step_year1", P1[i], age1[i], a + 1)):
            e = Bat(code, tgt); mo = P[0] + P[2]; emo = e[0] + e[2]
            rows.append(dict(state=ST, shift=shift, sw_hw=code, curve=g, inv_age=a, check=lab, state_age=int(ag), target_age=tgt,
                             merch_other_C=mo, target_merch_other_C=emo, foliage_C=P[1], target_foliage_C=e[1],
                             rel_err_merch_other=(mo - emo) / emo if emo > 0 else np.nan,
                             max_abs_err_components=float(np.abs(P - e).max()),
                             shortfall_over_I_a=((emo - mo) / (Iat(code, tgt)[0] + Iat(code, tgt)[2])) if 1 <= tgt <= K and abs(Iat(code, tgt)[0] + Iat(code, tgt)[2]) > 0 else np.nan))
R = pd.DataFrame(rows); R.to_csv(os.path.join(OUT, f"unit_shift_{ST}.csv"), index=False)
pd.set_option("display.width", 250); print(R.drop(columns=["state"]).to_string())
reg = R[(R["shift"] == 1) & ~((R.inv_age == 1))]
ok = (reg.max_abs_err_components <= 1e-15 + 1e-12 * reg.target_merch_other_C.abs()).all()
print("UNIT", ST, "registered shift, ages != 1, end_spinup and step_year1:", "PASS" if ok else "FAIL", "max abs err", float(reg.max_abs_err_components.max()),
      "| age 1 (not testable) end_spinup merch_other_C", R[(R["shift"] == 1) & (R.inv_age == 1) & (R.check == "end_spinup")].merch_other_C.tolist())
