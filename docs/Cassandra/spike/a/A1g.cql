ALTER KEYSPACE system_traces WITH replication = {'class':'NetworkTopologyStrategy','helios-dc1':1};
CONSISTENCY LOCAL_QUORUM;
SERIAL CONSISTENCY LOCAL_SERIAL;
TRACING ON;
INSERT INTO spike.resources (tenant_id,resource_type,id,version_id,write_id,data) VALUES ('t1','Patient','p3',1,33333333-3333-3333-3333-333333333333,'v1') IF NOT EXISTS;
UPDATE spike.resources SET version_id=2 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p3' IF version_id = 1 AND deleted_at = null;
TRACING OFF;
