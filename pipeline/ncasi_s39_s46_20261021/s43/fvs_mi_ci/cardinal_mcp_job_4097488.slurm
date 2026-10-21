#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsci_key
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:20:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_mi_ci/fvsci_key_%j.log
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015
python3 - <<'PYEOF'
import pandas as pd
for st in ['ME','NH','VT','MI','WI','MN']:
    P=pd.read_csv(f'fvs/work/pairs_{st}.csv',dtype=str)
    pat=P.pair_id.str.replace(r'[0-9]','d',regex=True).str.replace(r'd+','N',regex=True).value_counts().head(2)
    print(st,len(P),dict(pat),'t1==pid',round((P.t1_id==P.pair_id).mean(),3),'pid_in_t1set',round(P.pair_id.isin(set(P.t1_id)).mean(),3),
          'pid_contains_t1',round(sum(t in p for t,p in zip(P.t1_id,P.pair_id))/len(P),3))
PYEOF
ls fvs/ | head -40
grep -l "pair_id" fvs/*.py fvs/*.R 2>/dev/null | head
for f in $(grep -l "pair_id" fvs/*.py fvs/*.R 2>/dev/null | head -3); do echo "== $f"; grep -n "pair_id\s*=\|pair_id\"\] =\|\"pair_id\":\|pair_id =\|mutate(pair_id\|PREV_PLT\|t1_id" $f | head -8; done
PYEOF2=1

