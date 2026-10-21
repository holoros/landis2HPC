#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsci_boot
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_mi_ci/fvsci_bootb_%j.log
set -uo pipefail
O=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_mi_ci
mkdir -p $O; cd $O
cat > fvsci_boot_20261019b.py <<'PYEOF'
#!/usr/bin/env python3
"""NCASI s43 Track D: bootstrap intervals for FVS mortality recal holdout ratios (19 Oct 2026).
Reads s41 holdout pair outputs (job 15553462) read-only. No refit, no FVS runs. Aggregates only in outputs.
Same ratio-of-means definitions as s41/fvs/fvsmr_score_20261015.py. 2,000 resamples, seed 20261019.
Pair bootstrap, plus cluster bootstrap by plot (plot = connected component of pair t1/t2 inventory ids)."""
from pathlib import Path
import numpy as np, pandas as pd

G = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015")
W0 = G / "fvs/work"; W = G / "s41/fvs/work"; O = G / "s43/fvs_mi_ci"
REF = pd.read_csv(G / "s41/fvs/fvs_mortrecal_holdout_results_20261015.csv")
K = 0.00112085; B = 2000; SEED = 20261019
VAR = {"ME": "NE", "NH": "NE", "VT": "NE", "MI": "LS", "WI": "LS", "MN": "LS"}
Q = ["gross", "mort", "net", "dense_gross"]
REFCOL = {"gross": "ratio_gross", "mort": "ratio_mort", "net": "ratio_net", "dense_gross": "ratio_dense_gross"}
OLDLO = {"gross": "ratio_gross_lo", "mort": "ratio_mort_lo", "net": "ratio_net_lo", "dense_gross": "ratio_dense_lo"}
OLDHI = {"gross": "ratio_gross_hi", "mort": "ratio_mort_hi", "net": "ratio_net_hi", "dense_gross": "ratio_dense_hi"}
BAND = {"gross": (0.85, 1.15), "mort": (0.85, 1.15), "net": (0.85, 1.15), "dense_gross": (0.80, 1.25)}

def find(par, a):
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a

def plot_key(P):
    """Plot cluster over the full pair file (fit + holdout): pair_id is the t2 PLT_CN and t1_id is PREV_PLT_CN
    (fvs/fvsgate_pairs_20261015.R). Union t1 and t2 CNs (whitespace stripped); a component is one physical plot's
    remeasurement chain. Returns dict pair_id(stripped) -> component root."""
    t1 = P.t1_id.astype(str).str.strip().to_numpy(); t2 = P.pair_id.astype(str).str.strip().to_numpy()
    par = {}
    for a, b in zip(t1, t2):
        par.setdefault(a, a); par.setdefault(b, b)
        ra, rb = find(par, a), find(par, b)
        if ra != rb: par[rb] = ra
    return {b: find(par, b) for b in t2}

rngp = np.random.default_rng(SEED); rngc = np.random.default_rng(SEED)  # separate streams
rows, diag, mism = [], [], []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    P = pd.read_csv(W0 / f"pairs_{st}.csv", dtype={"pair_id": str, "t1_id": str})
    R = pd.read_csv(W / f"hold_pairs_{st}.csv", dtype={"pair_id": str})
    PK = plot_key(P)
    for arm in R.arm.unique():
        x = R[R.arm == arm].merge(P, on="pair_id", how="left")
        x = x[x.ok].copy().reset_index(drop=True)
        x["fvs_gg"] = x.fvs_surv / x.cycle * K; x["fvs_mort_r"] = x.fvs_mort / x.cycle * K
        x["fvs_net"] = x.fvs_gg - x.fvs_mort_r
        A = x[["obs_gg", "obs_mort", "obs_net", "fvs_gg", "fvs_mort_r", "fvs_net"]].to_numpy()
        dn = (x.B1_Mgha >= 200).to_numpy()
        def ratios(idx):
            m = A[idx].mean(0); d = dn[idx]
            md = A[idx][d].mean(0) if d.any() else np.full(6, np.nan)
            return np.array([m[3] / m[0], m[4] / m[1], m[5] / m[2], md[3] / md[0]])
        n = len(x); est = ratios(np.arange(n))
        ref = REF[(REF.state == st) & (REF.arm == arm)].iloc[0]
        for j, q in enumerate(Q):
            if not abs(est[j] - ref[REFCOL[q]]) < 0.0005:
                mism.append(f"{st} {arm} {q} est {est[j]:.4f} ref {ref[REFCOL[q]]:.4f}")
        bp = np.array([ratios(rngp.integers(0, n, n)) for _ in range(B)])
        cl = np.array([PK[p.strip()] for p in x.pair_id.astype(str)])
        codes, inv = np.unique(cl, return_inverse=True); nc = len(codes)
        members = [np.flatnonzero(inv == c) for c in range(nc)]
        sizes = np.array([len(m) for m in members])
        if nc < n:
            bc = np.array([ratios(np.concatenate([members[c] for c in rngc.integers(0, nc, nc)])) for _ in range(B)])
        else:
            bc = None
        diag.append(dict(state=st, arm=arm, pairs=n, dense_pairs=int(dn.sum()), plot_clusters=nc,
                         max_pairs_per_plot=int(sizes.max()), plots_with_2plus=int((sizes > 1).sum())))
        for j, q in enumerate(Q):
            lo, hi = BAND[q]
            r = dict(state=st, variant=VAR[st], arm=arm, quantity=q, pairs=n, dense_pairs=int(dn.sum()),
                     point=est[j], ref_s41=ref[REFCOL[q]],
                     pair_lo=np.nanpercentile(bp[:, j], 2.5), pair_hi=np.nanpercentile(bp[:, j], 97.5),
                     pair_frac_in_band=np.mean((bp[:, j] >= lo) & (bp[:, j] <= hi)),
                     s41_1000_lo=ref[OLDLO[q]], s41_1000_hi=ref[OLDHI[q]],
                     band_lo=lo, band_hi=hi, verdict="PASS" if lo <= est[j] <= hi else "FAIL")
            if bc is not None:
                r.update(clus_lo=np.nanpercentile(bc[:, j], 2.5), clus_hi=np.nanpercentile(bc[:, j], 97.5),
                         clus_frac_in_band=np.mean((bc[:, j] >= lo) & (bc[:, j] <= hi)))
            rows.append(r)
res = pd.DataFrame(rows)
pd.DataFrame(diag).to_csv(O / "fvsci_cluster_diag_20261019b.csv", index=False)
(O / "fvsci_repro_check_20261019b.txt").write_text("MISMATCH\n" + "\n".join(mism) if mism else "REPRO_OK all arms all quantities match s41 to 3 dp\n")
res.round(4).to_csv(O / "fvsci_boot_results_20261019b.csv", index=False)
print(open(O / "fvsci_repro_check_20261019b.txt").read())
print(pd.DataFrame(diag).to_string(index=False))
k = res[res.arm.isin(["recal_state", "recal_variant"])]
print(k.reindex(columns=["state", "arm", "quantity", "point", "pair_lo", "pair_hi", "clus_lo", "clus_hi", "pair_frac_in_band", "clus_frac_in_band", "verdict"]).round(3).to_string(index=False))
print("BOOT_DONE")
PYEOF
md5sum fvsci_boot_20261019b.py
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015
md5sum $G/s41/fvs/work/hold_pairs_*.csv $G/fvs/work/pairs_*.csv $G/s41/fvs/fvs_mortrecal_holdout_results_20261015.csv
module purge
python3 fvsci_boot_20261019b.py || exit 5
echo "JOB EXIT 0"

