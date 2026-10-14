import os
import sys,re
L=sys.argv[1]
S=os.path.dirname(os.path.abspath(__file__))+'/'
ins={};upd={}
for l in open(S+'ack_%s.txt'%L):
    k,n,t=l.split(); (ins if k=='n' else upd)[int(n)]=int(t)
rows={}
for l in open(S+'rows_%s.txt'%L):
    m=re.match(r'\s*p-(\d+)\s*\|\s*(\d+)',l)
    if m: rows[int(m[1])]=int(m[2])
mx=max(rows) if rows else 0
print('acked inserts',len(ins),'last',max(ins),'| acked updates',len(upd),'last',max(upd))
print('rows present',len(rows),'max n',mx,'gaps below max',[i for i in range(1,mx+1) if i not in rows][:10])
li=[n for n in ins if n not in rows]; print('acked inserts lost',len(li),'(min lost n',min(li) if li else None,')')
lu=[n for n in upd if rows.get(n)!=2]; print('acked updates present with v2',len(upd)-len(lu),'lost',len(lu))
print('unacked-but-present',[n for n in rows if n not in ins])
lastt=max(ins.values())
if li: print('seconds lost: first lost ack to last ack = %.2f s'%((lastt-ins[min(li)])/1000), '; last present ack vs last ack = %.2f s'%((lastt-ins[mx])/1000 if mx in ins else -1))
