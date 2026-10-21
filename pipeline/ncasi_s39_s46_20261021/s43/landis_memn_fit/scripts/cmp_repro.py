import csv,sys
a={r['run']:r for r in csv.DictReader(open(sys.argv[1]))}; b={r['run']:r for r in csv.DictReader(open(sys.argv[2]))}
for run in sorted(b):
    if run not in a: print(run,'missing in ref'); continue
    d=max(abs(float(a[run][c])-float(b[run][c])) for c in ['t0_Tg','t10_Tg','anpp_mean','mort_5_10','net_0_10','r_stock','r_prod','r_mort','r_net','ratio_high'])
    print(run, 'r_stock %.4f r_prod %.3f r_mort %.3f r_net %.3f high %.3f pass %s' % tuple([float(b[run][c]) for c in ['r_stock','r_prod','r_mort','r_net','ratio_high']]+[b[run]['pass']]), 'maxabsdiff_vs_s43b %.3g' % d)
