"""s41 probe v2: volume to biomass factor rows and turnover parameters actually
used by the FVS_FIAW_NEW cell, per state, and the libcbm packaged default rows
for the Canadian donor spatial units. Read only."""
import os, json, sqlite3, hashlib
import pandas as pd
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 80); pd.set_option("display.max_rows", 400)
R = "/users/PUOM0008/crsfaaron/cbm_states/states"
def md5(p): return hashlib.md5(open(p,"rb").read()).hexdigest()
SUQ = """select su.id su_id, abt.name admin, ebt.name eco, eb.turnover_parameter_id, ab.stump_parameter_id, su.mean_annual_temperature mat
  from spatial_unit su join admin_boundary ab on su.admin_boundary_id=ab.id
  join admin_boundary_tr abt on abt.admin_boundary_id=ab.id and abt.locale_id=1
  join eco_boundary eb on su.eco_boundary_id=eb.id
  join eco_boundary_tr ebt on ebt.eco_boundary_id=eb.id and ebt.locale_id=1"""
SPQ = """select s.id species_id, st.name, s.genus_id, s.forest_type_id from species s join species_tr st on st.species_id=s.id and st.locale_id=1"""
def factors(con, suid, names):
    sp = pd.read_sql(SPQ, con); sp = sp[sp.name.isin(names)]
    v = pd.read_sql(f"select vs.species_id, f.* from vol_to_bio_species vs join vol_to_bio_factor f on f.id=vs.vol_to_bio_factor_id where vs.spatial_unit_id={suid}", con)
    out = sp.merge(v, on="species_id", how="left")
    miss = out[out["id"].isna()]
    if len(miss):  # genus fallback
        g = pd.read_sql(f"select vg.genus_id, f.* from vol_to_bio_genus vg join vol_to_bio_factor f on f.id=vg.vol_to_bio_factor_id where vg.spatial_unit_id={suid}", con)
        print("  genus fallback needed for", list(miss.name), "genus rows:", len(g))
    return out
rows = []
for ST in ["ME","NH","VT","MI","WI","MN"]:
    print("\n" + "="*30, ST)
    src = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW"
    m = json.load(open(f"{src}/sit_config.json"))["mapping_config"]
    smap = pd.DataFrame(m["species"]["species_mapping"]); print(smap.to_string())
    spm = m["spatial_units"]; print("SU", spm)
    db = f"{R}/{ST}/data/processed/cbm_defaults_{ST}.db"; print("DB md5", md5(db))
    con = sqlite3.connect(db)
    su = pd.read_sql(SUQ, con)
    sel = su[(su.admin == spm["admin_boundary"]) & (su.eco == spm["eco_boundary"])]
    print(sel.to_string())
    suid = int(sel.su_id.iloc[0])
    f = factors(con, suid, list(smap.default_species.unique()))
    f.insert(0, "state", ST); f.insert(1, "su_id", suid); f["source"] = "state_db"
    rows.append(f)
    print(f.T.to_string())
    tp = int(sel.turnover_parameter_id.iloc[0])
    print("TURNOVER id", tp); print(pd.read_sql(f"select * from turnover_parameter where id={tp}", con).T.to_string())
    try:
        print("STUMP", pd.read_sql(f"select * from stump_parameter where id={int(sel.stump_parameter_id.iloc[0])}", con).T.to_string())
    except Exception as e: print("stump query failed", e)
    # which species ids exist and are softwood (forest_type_id 1) vs hardwood (3)
    if ST == "ME":
        print("FOREST TYPES", pd.read_sql("select * from forest_type_tr where locale_id=1", con).to_string())
    con.close()
import libcbm.resources
d = libcbm.resources.get_cbm_defaults_path(); print("\nLIBCBM DEFAULT DB", d, md5(d))
con = sqlite3.connect(d)
su = pd.read_sql(SUQ, con)
names = sorted(set(pd.concat(rows).name))
for adm, eco in [("New Brunswick","Atlantic Maritime"), ("Ontario","Mixedwood Plains"), ("Ontario","Boreal Shield East")]:
    s = su[(su.admin==adm) & (su.eco==eco)]
    if not len(s): print("no SU", adm, eco); continue
    suid = int(s.su_id.iloc[0]); print("DEFAULT", adm, eco, s.to_string())
    f = factors(con, suid, names); f.insert(0, "state", f"default_{adm}_{eco}"); f.insert(1, "su_id", suid); f["source"] = "libcbm_default"
    rows.append(f)
    tp = int(s.turnover_parameter_id.iloc[0]); print("DEFAULT TURNOVER", pd.read_sql(f"select * from turnover_parameter where id={tp}", con).T.to_string())
con.close()
out = pd.concat(rows)
out.to_csv("s41_volbio_factors_used_20261015.csv", index=False)
print("wrote s41_volbio_factors_used_20261015.csv", out.shape)
