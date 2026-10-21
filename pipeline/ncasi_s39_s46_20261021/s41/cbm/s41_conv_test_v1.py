"""s41 conversion test: apply each state's CBM Boudewyn chain (factor rows of the
state AIDB, species mapping of the FVS_FIAW_NEW cell) to the merchantable net
volume FIA actually measured on each forest condition, and compare with NSVB on
the same conditions. Isolates the volume to biomass parameters from the yield
curve level. Aggregates by state and forest type group are written."""
import json, sqlite3, numpy as np, pandas as pd
def factor_row(con, suid, sp_name):
    sid, gid, ftid = con.execute("select s.id, s.genus_id, s.forest_type_id from species s join species_tr t on t.species_id=s.id and t.locale_id=1 where t.name=?", (sp_name,)).fetchone()
    for q, k in (("select vol_to_bio_factor_id from vol_to_bio_species where spatial_unit_id=? and species_id=?", sid),
                 ("select vol_to_bio_factor_id from vol_to_bio_genus where spatial_unit_id=? and genus_id=?", gid),
                 ("select vol_to_bio_factor_id from vol_to_bio_forest_type where spatial_unit_id=? and forest_type_id=?", ftid)):
        r = con.execute(q, (suid, k)).fetchone()
        if r: return pd.read_sql(f"select * from vol_to_bio_factor where id={r[0]}", con).iloc[0].to_dict()
def boud(V, f):
    V = np.asarray(V, float); pos = V > 0; Vp = np.where(pos, V, 1.0)
    bm = f["a"] * Vp ** f["b"]
    bnm = np.minimum(f["k_nonmerch"] + f["a_nonmerch"] * bm ** f["b_nonmerch"], f["cap_nonmerch"]) * bm
    bsnm = np.minimum(f["k_sap"] + f["a_sap"] * bnm ** f["b_sap"], f["cap_sap"]) * bnm
    L = np.log(Vp + 5)
    ea = np.exp(f["a1"] + f["a2"] * Vp + f["a3"] * L); eb = np.exp(f["b1"] + f["b2"] * Vp + f["b3"] * L); ec = np.exp(f["c1"] + f["c2"] * Vp + f["c3"] * L)
    psw = 1 / (1 + ea + eb + ec); pbk = ea * psw; pbr = eb * psw; pfl = ec * psw
    lo = Vp < f["min_volume"]; hi = Vp > f["max_volume"]
    for arr, lk, hk in ((psw, "low_stemwood_prop", "high_stemwood_prop"), (pbk, "low_stembark_prop", "high_stembark_prop"),
                        (pbr, "low_branches_prop", "high_branches_prop"), (pfl, "low_foliage_prop", "high_foliage_prop")):
        arr[lo] = f[lk]; arr[hi] = f[hk]
    tot = bsnm / psw
    woody = np.where(pos, bsnm + tot * pbk + tot * pbr, 0.0); fol = np.where(pos, tot * pfl, 0.0)
    return woody, fol
C = pd.read_csv("s41_fia_condtable_20261015_CARDINAL_ONLY.csv")
rows = []
for ST in ["ME","NH","VT","MI","WI","MN"]:
    cfg = json.load(open(f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW/sit_config.json"))["mapping_config"]
    smap = {int(x["user_species"].split()[1]): x["default_species"] for x in cfg["species"]["species_mapping"]}
    con = sqlite3.connect(f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db")
    suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
        join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
        (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
    d = C[C.state == ST].copy()
    d["grp"] = d.TYPGRPCD.where(d.TYPGRPCD.isin(list(smap)), 999)  # groups not in the CBM classifier set go to FT 999 mapping
    d["cbm_woody"] = 0.0; d["cbm_fol"] = 0.0
    for gcode, sp in smap.items():
        i = d.grp == gcode
        if i.any():
            w, f = boud(d.loc[i, "vnet_m3ha"].values, factor_row(con, suid, sp)); d.loc[i, "cbm_woody"] = w; d.loc[i, "cbm_fol"] = f
    con.close()
    for c in ["cbm_woody","cbm_fol","ag_tha","fol_tha","vnet_m3ha"]: d[c + "_tot"] = d[c] * d.area_ha / 1e6
    for key, gdf in list(d.groupby("grp")) + [("ALL", d)]:
        s = gdf[[c for c in gdf.columns if c.endswith("_tot")] + ["area_ha"]].sum()
        rows.append(dict(state=ST, group=key, species=smap.get(key, "") if key != "ALL" else "", area_Mha=s.area_ha / 1e6, fia_vnet_Mm3=s.vnet_m3ha_tot,
                         fia_woody_Tg=s.ag_tha_tot, chain_woody_on_fia_vol_Tg=s.cbm_woody_tot, ratio_woody=s.cbm_woody_tot / s.ag_tha_tot,
                         fia_foliage_Tg=s.fol_tha_tot, chain_foliage_Tg=s.cbm_fol_tot, ratio_foliage=s.cbm_fol_tot / s.fol_tha_tot if s.fol_tha_tot > 0 else np.nan))
R = pd.DataFrame(rows); R.to_csv("s41_conv_test_on_fia_volumes_20261015.csv", index=False)
pd.set_option("display.width", 250); print(R.round(3).to_string())
