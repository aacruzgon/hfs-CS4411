import subprocess,re
P="tenant_id='t1' AND resource_type='Observation'"
def q(c):
    return subprocess.run(["docker","exec","-i","spike-a-cassandra-1","cqlsh","-e","CONSISTENCY LOCAL_QUORUM; "+c],capture_output=True,text=True).stdout
def rows(o): return [(m.group(1),m.group(2)) for m in re.finditer(r'^ (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\.000000\+0000 \| (\S+)',o,re.M)]
print("-- A3 keyset paging: 5 pages x LIMIT 10 starting after cursor (00:41:40, obs03501); cursor = last row of previous page")
ct,ci='2026-01-01 00:41:40','obs03501'
gt=rows(q(f"SELECT last_updated,id FROM spike.resources_by_type WHERE {P} AND (last_updated,id) < ('{ct}+0000','{ci}') LIMIT 50;"))
paged=[]
for p in range(1,6):
    c=f"SELECT last_updated,id FROM spike.resources_by_type WHERE {P} AND (last_updated,id) < ('{ct}+0000','{ci}') LIMIT 10;"
    print("\n-- page",p,":",c); o=q(c); print(o.strip())
    r=rows(o); paged+=r; ct,ci=r[-1]
print("\n-- ground truth LIMIT 50 equals concatenation of pages:", gt==paged, "| rows:",len(paged),"| distinct:",len(set(paged)))
print("-- pages whose last row tied with next page's first row (split a tie group):")
for i in range(9,50,10):
    if i+1<50 and paged[i][0]==paged[i+1][0]: print("   boundary after row",i+1,paged[i],"| next",paged[i+1])
