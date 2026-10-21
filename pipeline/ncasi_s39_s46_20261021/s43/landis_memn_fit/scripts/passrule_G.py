# Track G pass rule: registered gate (scorer 'pass') AND BiomassMax(max over species)/FIA p99 in [1.15, 2.83] in every ecoregion;
# tie rule: smallest Chebyshev distance in grid steps from (A 2.5, B 3.0); ties -> lower B, then lower A.
import csv,sys,collections
tag=sys.argv[1]; O='out/'
g=list(csv.DictReader(open(O+'behav_gate_memn_%s.csv'%tag)))
bm=collections.defaultdict(list)
for r in csv.DictReader(open(O+'bmax_vs_fia_p99_%s.csv'%tag)):
    if ':' in r['table']: bm[r['table'].split(':',1)[1]].append((r['eco'],float(r['ratio_max_to_p99'])))
AG=[2.25,2.5,2.75]; BG=[2.5,3.0,3.5]
out=[]
for r in g:
    rn=r['run']; spec=r['spec']; A=float(spec.split('anpp=')[1].split()[0]); B=float(spec.split('bmx=')[1].split()[0])
    eco=sorted(bm[rn]); rmin=min(x[1] for x in eco); rmax=max(x[1] for x in eco)
    bok=all(1.15<=x[1]<=2.83 for x in eco)
    full=(r['pass']=='TRUE') and bok
    d=max(abs(AG.index(A)-1),abs(BG.index(B)-1)) if A in AG and B in BG else -1
    out.append(dict(state=r['state'],run=rn,A=A,B=B,gate=r['pass'],bmax_p99_min=round(rmin,3),bmax_p99_max=round(rmax,3),bmax_rule=bok,full_pass=full,cheb=d,
        eco_ratios=' '.join('%s:%.2f'%x for x in eco)))
w=csv.DictWriter(open(O+'passrule_%s_G.csv'%tag,'w'),fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
for st in sorted(set(o['state'] for o in out)):
    P=[o for o in out if o['state']==st and o['full_pass']]
    P.sort(key=lambda o:(o['cheb'],o['B'],o['A']))
    print(st,'passing points:',len(P),'chosen:',P[0]['run'] if P else 'NONE')
for o in sorted(out,key=lambda o:(o['state'],o['A'],o['B'])): print(o['state'],o['A'],o['B'],o['gate'],o['bmax_rule'],o['eco_ratios'])
