"""s41 probe: what volume to biomass parameters and turnover parameters does the
FVS_FIAW_NEW CBM cell actually use, per state. Read only. Prints to stdout."""
import os, json, sqlite3, hashlib, glob
import pandas as pd
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 60); pd.set_option("display.max_rows", 400)
R = "/users/PUOM0008/crsfaaron/cbm_states/states"
def md5(p): return hashlib.md5(open(p,"rb").read()).hexdigest()
for ST in ["ME","NH","VT","MI","WI","MN"]:
    print("\n" + "="*30, ST)
    src = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW"
    cfg = json.load(open(f"{src}/sit_config.json"))
    print("MAPPING", json.dumps(cfg["mapping_config"]))
    print(open(f"{src}/classifiers.csv").read())
    gy = pd.read_csv(f"{src}/growth_and_yield.csv"); print("GY shape", gy.shape); print(gy.iloc[:4, :16].to_string())
    inv = pd.read_csv(f"{src}/inventory.csv"); print("INV cols", list(inv.columns)); print(inv.head(3).to_string())
    db = f"{R}/{ST}/data/processed/cbm_defaults_{ST}.db"
    print("DB", db, md5(db))
    for f in sorted(glob.glob(f"{R}/{ST}/data/processed/*")):
        b = os.path.basename(f)
        if any(k in b for k in ["vol_to_bio","props","cbm_defaults","changelog","boudewyn"]):
            print("  file", b, os.path.getsize(f), md5(f) if f.endswith(".db") or "db.bak" in b else "")
    for f in [f"{R}/{ST}/data/processed/vol_to_bio_{ST}.csv", f"{R}/{ST}/data/processed/vol_to_bio_props_{ST}.csv"]:
        if os.path.exists(f):
            print("CSV", os.path.basename(f)); print(pd.read_csv(f).to_string())
    for f in sorted(glob.glob(f"{R}/{ST}/data/processed/*changelog*")):
        print("CHANGELOG", os.path.basename(f)); print(open(f).read()[:3000])
    con = sqlite3.connect(db)
    tabs = [r[0] for r in con.execute("select name from sqlite_master where type='table'")]
    if ST == "ME": print("TABLES", tabs)
    for t in ["vol_to_bio_factor","vol_to_bio_species","vol_to_bio_genus","vol_to_bio_forest_type","spatial_unit","eco_boundary","turnover_parameter","admin_boundary"]:
        if t in tabs and ST == "ME":
            print("SCHEMA", t, [r[1] for r in con.execute(f"pragma table_info({t})")])
    su = pd.read_sql("""select su.id su_id, ab.id admin_id, abt.name admin, eb.id eco_id, ebt.name eco, eb.turnover_parameter_id
        from spatial_unit su join admin_boundary ab on su.admin_boundary_id=ab.id
        join admin_boundary_tr abt on abt.admin_boundary_id=ab.id and abt.locale_id=1
        join eco_boundary eb on su.eco_boundary_id=eb.id
        join eco_boundary_tr ebt on ebt.eco_boundary_id=eb.id and ebt.locale_id=1""", con)
    m = cfg["mapping_config"]
    spm = m.get("spatial_units", {})
    print("SU mapping", spm)
    names = set()
    for k in ("admin_mapping","eco_mapping"):
        if k in spm:
            for x in spm[k]: names.add(x.get("default_admin_boundary", x.get("default_eco_boundary")))
    if "default_spuid" in spm: print("default_spuid", spm["default_spuid"])
    sel = su[su.admin.isin(names) | su.eco.isin(names) | su.su_id.isin([spm.get("default_spuid", -1)])]
    if spm.get("mapping_mode") == "SingleDefaultSpatialUnit" or "default_spuid" in spm:
        sel = su[su.su_id == spm.get("default_spuid")]
    else:
        a = [x["default_admin_boundary"] for x in spm.get("admin_mapping", [])]; e = [x["default_eco_boundary"] for x in spm.get("eco_mapping", [])]
        sel = su[su.admin.isin(a) & su.eco.isin(e)] if a and e else sel
    print(sel.to_string())
    spn = [x["default_species"] for x in m["species"]["species_mapping"]]
    sp = pd.read_sql("select s.id species_id, st.name from species s join species_tr st on st.species_id=s.id and st.locale_id=1", con)
    sp = sp[sp.name.isin(spn)]
    print(sp.to_string())
    for suid in sel.su_id:
        v = pd.read_sql(f"select vs.spatial_unit_id, vs.species_id, vs.vol_to_bio_factor_id, f.* from vol_to_bio_species vs join vol_to_bio_factor f on f.id=vs.vol_to_bio_factor_id where vs.spatial_unit_id={suid}", con)
        v = v.merge(sp, on="species_id", how="inner")
        print("VOLBIO for SU", suid); print(v.T.to_string())
        tp = sel.loc[sel.su_id==suid, "turnover_parameter_id"].iloc[0]
        print("TURNOVER", pd.read_sql(f"select * from turnover_parameter where id={tp}", con).T.to_string())
    con.close()
# libcbm packaged default db for comparison
try:
    import libcbm.resources
    d = libcbm.resources.get_cbm_defaults_path()
    print("LIBCBM DEFAULT DB", d, md5(d))
except Exception as e:
    print("default db lookup failed", e)
