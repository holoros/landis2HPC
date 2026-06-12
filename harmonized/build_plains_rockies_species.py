#!/usr/bin/env python3
"""build_plains_rockies_species.py - author the LANDIS extension-species scaffolds for
the 5 Plains/Rockies clusters (P1,P2,R1,R2,R3) from FIA basal-area dominance.

These clusters cannot warmstart from the eastern (IN/ME/MN) or PNW-westside (WA) floras
because their species pools differ: dry-conifer, pinyon-juniper, and prairie-margin
species are not in the parent pools and have no LANDIS SpeciesData yet. This script
turns the open-ended "parameterize from literature" step into a precise, data-driven
fill-in: it lists exactly which species dominate each cluster (from plains_rockies_
species_ba.csv) and which are NEW vs the warmstart parent, with the LANDIS-II
SpeciesData columns the literature step must fill, and a published-source hint per
species (most western dry-conifers have established LANDIS parameterizations).

Output: one cluster_<C>_extension_species.csv per cluster + a README.
SpeciesData columns (LANDIS-II core): longevity, sexual_maturity, shade_tolerance(1-5),
fire_tolerance(1-5), seed_disperse_effective(m), seed_disperse_max(m),
veg_reprod_prob, sprout_age_min, sprout_age_max, post_fire_regen(none|resprout|serotiny).
"""
import csv, os

# FIA SPCD -> common name (western/plains subset present in the dominance scan)
NAME = {
 15:"white fir",17:"grand fir",19:"subalpine fir",61:"Arizona cypress",63:"alligator juniper",
 64:"western juniper",65:"Utah juniper",66:"Rocky Mountain juniper",68:"eastern redcedar",
 69:"oneseed juniper",73:"western larch",93:"Engelmann spruce",94:"white spruce",
 101:"whitebark pine",106:"Colorado pinyon",108:"lodgepole pine",110:"shortleaf pine",
 113:"limber pine",116:"Jeffrey pine",122:"ponderosa pine",131:"loblolly pine",
 133:"singleleaf pinyon",202:"Douglas-fir",242:"western redcedar",263:"western hemlock",
 313:"boxelder",462:"hackberry",475:"curlleaf mountain-mahogany",544:"green ash",
 552:"honeylocust",602:"black walnut",611:"sweetgum",641:"Osage-orange",682:"red mulberry",
 742:"eastern cottonwood",746:"quaking aspen",756:"honey mesquite",802:"white oak",
 803:"Arizona white oak",812:"southern red oak",814:"Gambel oak",823:"bur oak",
 824:"blackjack oak",827:"water oak",835:"post oak",837:"black oak",951:"American basswood",
 971:"winged elm",972:"American elm",
}

# cluster -> (warmstart parent, member states, parent species pool already covered)
CLUSTERS = {
 "P1": dict(parent="MN+IN (eastern broadleaf / prairie margin)",
            states=["KS","NE","OK"],  # + e-CO,e-NM,e-TX split at run time
            note="Central/southern plains. Warmstart eastern broadleaf; add prairie-margin oaks, redcedar, mesquite, dry ponderosa."),
 "P2": dict(parent="MN (northern hardwood / aspen parkland)",
            states=["ND","SD"],       # + e-MT
            note="Northern plains + Black Hills. SD is ponderosa-dominated (Black Hills); add ponderosa, RM juniper, bur oak."),
 "R1": dict(parent="WA (PNW conifer)",
            states=["MT","ID","WY"],
            note="Northern Rockies. Add lodgepole, subalpine fir, Engelmann spruce, western larch, whitebark/limber pine."),
 "R2": dict(parent="WA + IN (mixed conifer / pinyon-juniper)",
            states=["CO","NM","AZ","UT"],
            note="Southern Rockies + Colorado Plateau. Add pinyon, junipers, Gambel oak, white fir, aspen, spruce-fir."),
 "R3": dict(parent="WA (sparse, pinyon-juniper end-member)",
            states=["NV"],
            note="Great Basin. Pinyon-juniper woodland end-member; add Utah juniper, singleleaf pinyon, mtn-mahogany."),
}

# species already in a typical eastern (E) or PNW-westside (W) LANDIS parent pool -> NOT new
PARENT_COVERED = {
 "P1": {544,602,742,802,837,951,972,131,110},          # eastern hardwoods/pines in IN/MN pool
 "P2": {544,746,313,972,951,94},                        # MN aspen-parkland pool
 "R1": {202,242,263,17},                                # WA PNW conifer pool
 "R2": {202,93,19,746,242,263},                         # WA + subalpine in pool
 "R3": {746},                                           # little overlap
}

# published LANDIS-II SpeciesData source hint (where established western parameterizations exist)
SRC = {
 19:"Loehman et al. (Glacier/N.Rockies LANDIS)",93:"Loehman et al.; Creutzburg et al.",
 108:"Loehman; Sierra/Blue Mtns LANDIS",122:"Creutzburg; Loudermilk Sierra LANDIS",
 202:"Creutzburg et al. (PNW LANDIS)",73:"Loehman et al.",101:"Keane whitebark LANDIS",
 113:"Keane; derive from 101",65:"derive (PJ woodland; sparse LANDIS lit)",
 69:"derive (PJ woodland)",66:"derive (juniper)",68:"E. redcedar - eastern LANDIS lit",
 106:"derive (pinyon; Bradford PJ studies)",133:"derive (pinyon)",
 814:"derive (Gambel oak; resprouter)",823:"bur oak - eastern LANDIS lit",
 835:"post oak - SE LANDIS lit",824:"blackjack oak - SE LANDIS lit",
 742:"cottonwood - riparian LANDIS lit",746:"aspen - established LANDIS lit",
 15:"white fir - Sierra LANDIS lit",17:"grand fir - PNW LANDIS lit",
 475:"derive (mtn-mahogany; no LANDIS lit)",756:"derive (mesquite; no LANDIS lit)",
 63:"derive (alligator juniper)",64:"derive (western juniper)",116:"Sierra LANDIS lit",
 803:"derive (AZ white oak)",263:"PNW LANDIS lit",242:"PNW LANDIS lit",
 94:"boreal LANDIS lit",313:"derive (boxelder)",462:"derive (hackberry)",
 544:"eastern LANDIS lit",971:"derive (winged elm)",972:"eastern LANDIS lit",
}

COLS = ["cluster","spcd","common_name","ba_states","is_new_vs_parent","needs_literature",
        "landis_source_hint","longevity","sexual_maturity","shade_tolerance",
        "fire_tolerance","seed_disperse_effective_m","seed_disperse_max_m",
        "veg_reprod_prob","post_fire_regen"]

def load_ba(path):
    by_state = {}
    with open(path) as fh:
        for r in csv.DictReader(fh):
            by_state.setdefault(r["state"], []).append((int(float(r["spcd"])), float(r["ba_share_pct"])))
    return by_state

def main():
    import sys
    ba_path = sys.argv[1] if len(sys.argv) > 1 else "plains_rockies_species_ba.csv"
    outdir = sys.argv[2] if len(sys.argv) > 2 else "."
    by_state = load_ba(ba_path)
    os.makedirs(outdir, exist_ok=True)
    readme = ["# Plains/Rockies LANDIS extension-species scaffolds",
              "",
              "Data-driven target lists for the 5 clusters that cannot warmstart from the eastern/PNW",
              "floras. Built from FIA basal-area dominance (top-8 species/state). Each cluster_<C>_",
              "extension_species.csv lists the species present, flags which are NEW vs the warmstart",
              "parent pool (needs_literature=yes), and gives a published-LANDIS source hint. The",
              "literature step fills longevity / maturity / tolerances / dispersal / regen, then:",
              "freeze cluster ref theta (add_state.sh on a seed state to convergence) ->",
              "cluster_<C>_reference_theta.csv -> onboard members.",
              ""]
    for cl, meta in CLUSTERS.items():
        # union species across cluster states, max BA share, track which states
        agg = {}
        for st in meta["states"]:
            for spcd, ba in by_state.get(st, []):
                agg.setdefault(spcd, {"ba":0.0,"states":[]})
                agg[spcd]["ba"] = max(agg[spcd]["ba"], ba)
                agg[spcd]["states"].append(f"{st}:{ba:.0f}%")
        covered = PARENT_COVERED.get(cl, set())
        rows = []
        for spcd, d in sorted(agg.items(), key=lambda kv: -kv[1]["ba"]):
            is_new = spcd not in covered
            rows.append({
              "cluster":cl,"spcd":spcd,"common_name":NAME.get(spcd,f"SPCD{spcd}"),
              "ba_states":";".join(d["states"]),
              "is_new_vs_parent":"yes" if is_new else "no",
              "needs_literature":"yes" if is_new else "no",
              "landis_source_hint":SRC.get(spcd,"derive") if is_new else "(in parent pool)",
              "longevity":"","sexual_maturity":"","shade_tolerance":"","fire_tolerance":"",
              "seed_disperse_effective_m":"","seed_disperse_max_m":"","veg_reprod_prob":"",
              "post_fire_regen":""})
        fn = os.path.join(outdir, f"cluster_{cl}_extension_species.csv")
        with open(fn, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=COLS); w.writeheader(); w.writerows(rows)
        n_new = sum(1 for r in rows if r["needs_literature"]=="yes")
        print(f"{cl}: {len(rows)} species, {n_new} need literature -> {fn}")
        readme += [f"## {cl} ({meta['parent']})",
                   f"States: {', '.join(meta['states'])}. {meta['note']}",
                   f"{n_new} of {len(rows)} species need LANDIS SpeciesData from literature.",
                   "New species: " + ", ".join(f"{r['common_name']}" for r in rows if r['needs_literature']=='yes'),
                   ""]
    with open(os.path.join(outdir,"README_plains_rockies_species.md"),"w") as fh:
        fh.write("\n".join(readme))
    print("README + 5 cluster scaffolds written to", outdir)

if __name__ == "__main__":
    main()
