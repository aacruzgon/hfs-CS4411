import re,glob,statistics as st,os,sys
R=sys.argv[1]
def num(s): return float(s.replace(',',''))
def res(f):
    t=open(f).read()
    g=lambda k: num(re.search(k+r'\s*:\s*([\d,\.]+)',t).group(1))
    return dict(ops=g('Op rate'),mean=g('Latency mean'),p50=g('Latency median'),p95=g('Latency 95th percentile'),p99=g('Latency 99th percentile'),err=g('Total errors'))
def mem(f):
    m=0
    for l in open(f):
        x=re.search(r'([\d\.]+)(MiB|GiB)\s*/',l)
        if x: m=max(m,float(x.group(1))*(1024 if x.group(2)=='GiB' else 1))
    return m
for w in ['lwt','write','read']:
    for c in 'SL':
        d=f'{R}/{c}-P2'
        rs=[res(f'{d}/{w}.run{i}.txt') for i in (1,2,3) if os.path.exists(f'{d}/{w}.run{i}.txt')]
        if not rs: continue
        med=lambda k: st.median(r[k] for r in rs)
        print(w,c,'ops med %.0f (min %.0f max %.0f)'%(med('ops'),min(r['ops'] for r in rs),max(r['ops'] for r in rs)),
          'mean %.2f p50 %.2f p95 %.2f p99 %.2f'%(med('mean'),med('p50'),med('p95'),med('p99')),'errs',[r['err'] for r in rs],'peakMiB %.0f'%mem(f'{d}/{w}.mem'),
          'runs',[r['ops'] for r in rs])
for c in 'SL':
    f=f'{R}/{c}-P1/oom.write.txt'
    if os.path.exists(f): r=res(f); print('P1 oom',c,r,'peakMiB %.0f'%mem(f'{R}/{c}-P1/oom.mem'),open(f'{R}/{c}-P1/oom.oom.txt').read().strip())
