import sys,time,os
for z in ['cassandra-driver-internal-only-3.29.0.zip','geomet-0.1.0.zip','pyasyncore-1.0.5-py3-none-any.zip','pure_sasl-0.6.2-py2-none-any.zip','futures-2.1.6-py2.py3-none-any.zip']:
    sys.path.insert(0,'/opt/cassandra/lib/'+z+('/cassandra-driver-3.29.0' if 'driver' in z else ''))
from cassandra.cluster import Cluster
from cassandra import ConsistencyLevel
from cassandra.policies import WhiteListRoundRobinPolicy
from cassandra.query import SimpleStatement
H='spike-c-cassandra-1'
RT=sys.argv[1]; OUT=sys.argv[2]
c=Cluster([H],load_balancing_policy=WhiteListRoundRobinPolicy([H]))
s=c.connect()
ins=s.prepare("INSERT INTO spike.resources (tenant_id,resource_type,id,version_id,data) VALUES ('t',?,?,1,'n') IF NOT EXISTS")
upd=s.prepare("UPDATE spike.resources SET version_id=2 WHERE tenant_id='t' AND resource_type=? AND id=? IF version_id=1")
for p in (ins,upd):
    p.consistency_level=ConsistencyLevel.LOCAL_QUORUM
    p.serial_consistency_level=ConsistencyLevel.LOCAL_SERIAL
f=open(OUT,'a',buffering=1)
n=0
while True:
    n+=1
    try:
        r=s.execute(ins,(RT,'p-%d'%n),timeout=5).one()
        if r.applied: f.write('n %d %d\n'%(n,time.time()*1000)); f.flush(); os.fsync(f.fileno())
        if n%10==0:
            m=n-5
            r=s.execute(upd,(RT,'p-%d'%m),timeout=5).one()
            if r.applied: f.write('u %d %d\n'%(m,time.time()*1000)); f.flush(); os.fsync(f.fileno())
    except Exception as e:
        print('ERROR at n=%d: %s'%(n,str(e)[:200]),flush=True); break
