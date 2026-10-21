import csv,sys
for r in sorted(csv.DictReader(open(sys.argv[1])), key=lambda r:(r['state'],r['run'])):
    if r['complete']!='TRUE': print(r['state'],r['run'],'INCOMPLETE'); continue
    print(r['state'],r['run'].split('_',2)[2] if r['run'].startswith('g_') else r['run'],' '.join('%.3f'%float(r[c]) for c in ['r_stock','r_prod','r_mort','r_net','ratio_high']),r['pass'])
