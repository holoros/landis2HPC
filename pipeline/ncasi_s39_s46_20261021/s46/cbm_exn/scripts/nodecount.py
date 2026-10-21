import pandas as pd, sys
sys.path.insert(0, "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts")
src = open("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts/L5_curve_roundtrip.py").read()
i = src.index("FTMAPS = dict("); j = src.index("FTMAP = FTMAPS[ST]"); exec(src[i:j])
sh = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/nsvb_shares_trackL_20261020.csv")
for st, M in FTMAPS.items():
    s = sh[sh.state == st]; out = []
    for ft, g in M.items():
        tg = int(ft[2:]); grp = [int(f[2:]) for f, gg in M.items() if gg == g]
        own = s[(s.TYPGRPCD == tg) & (s.n_cond >= 10)].aclass.nunique()
        pool = s[s.TYPGRPCD.isin(grp)].groupby("aclass").n_cond.sum(); pool = int((pool >= 10).sum())
        out.append(f"{ft}->{g} own{own} pool{pool} ncond{int(s[s.TYPGRPCD==tg].n_cond.sum())}")
    print(st, "; ".join(out))
