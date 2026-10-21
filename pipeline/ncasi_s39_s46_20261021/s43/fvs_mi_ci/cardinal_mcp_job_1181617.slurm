#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsci_leak
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:20:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_mi_ci/fvsci_leak_%j.log
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_mi_ci
python3 - <<'PYEOF'
import importlib.util, pandas as pd, hashlib
spec = importlib.util.spec_from_file_location("b", "fvsci_boot_20261019b.py")
src = open("fvsci_boot_20261019b.py").read().split("rngp = ")[0]
ns = {}; exec(src, ns)
G = ns["G"]; out = []
for st in ["ME","NH","VT","MI","WI","MN"]:
    P = pd.read_csv(G/"fvs/work"/f"pairs_{st}.csv", dtype={"pair_id": str, "t1_id": str})
    H = set(pd.read_csv(G/"s41/fvs/work"/f"hold_pairs_{st}.csv", dtype={"pair_id": str}).pair_id.str.strip())
    PK = ns["plot_key"](P); pid = P.pair_id.str.strip()
    hm = pid.apply(lambda p: int(hashlib.md5(p.encode()).hexdigest()[:8], 16) % 2)
    d = pd.DataFrame({"plot": pid.map(PK), "hold": pid.isin(H)})
    g = d.groupby("plot").hold.agg(["any", "all"])
    hp = g[g["any"]]
    out.append(dict(state=st, pairs=len(d), hold_pairs=int(d.hold.sum()), hold_plots=len(hp),
                    hold_plots_also_in_fit=int((~hp["all"]).sum()), frac=round((~hp["all"]).mean(), 3),
                    md5_mod2_eq1_frac_hold=round(hm[d.hold].mean(), 3), md5_mod2_eq1_frac_nonhold=round(hm[~d.hold].mean(), 3)))
r = pd.DataFrame(out); r.to_csv("fvsci_split_plot_overlap_20261019.csv", index=False); print(r.to_string(index=False))
PYEOF

