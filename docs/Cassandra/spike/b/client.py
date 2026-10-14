import sys,time
for z in ['cassandra-driver-internal-only-3.29.0.zip','geomet-0.1.0.zip','pyasyncore-1.0.5-py3-none-any.zip','pure_sasl-0.6.2-py2-none-any.zip','futures-2.1.6-py2.py3-none-any.zip']:
    sys.path.insert(0,'/opt/cassandra/lib/'+z+('/cassandra-driver-3.29.0' if 'driver' in z else ''))
from cassandra.cluster import Cluster
from cassandra.query import BatchStatement, BatchType
from cassandra import ConsistencyLevel
from cassandra.policies import WhiteListRoundRobinPolicy
from cassandra.cluster import ExecutionProfile
c=Cluster(['spike-b-cassandra-1'],load_balancing_policy=WhiteListRoundRobinPolicy(['spike-b-cassandra-1']))
s=c.connect()
ps=s.prepare("INSERT INTO spike.resources (tenant_id,resource_type,id,version_id,data) VALUES ('t','B4',?,1,?)")
f=open('/out/acked.txt','a',buffering=1)
n=0
while True:
    n+=1
    b=BatchStatement(BatchType.LOGGED,consistency_level=ConsistencyLevel.LOCAL_QUORUM)
    for p in 'abc': b.add(ps,('%s-%d'%(p,n),'batch %d'%n))
    try: s.execute(b,timeout=5)
    except Exception as e:
        print('ERROR at n=%d: %s'%(n,str(e)[:200]),flush=True); break
    f.write('%d\n'%n)
