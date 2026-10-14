CONSISTENCY LOCAL_QUORUM;
SERIAL CONSISTENCY LOCAL_SERIAL;
-- a
INSERT INTO spike.resources (tenant_id,resource_type,id,version_id,write_id,data) VALUES ('t1','Patient','p1',1,11111111-1111-1111-1111-111111111111,'v1') IF NOT EXISTS;
INSERT INTO spike.resources (tenant_id,resource_type,id,version_id,write_id,data) VALUES ('t1','Patient','p1',1,11111111-1111-1111-1111-111111111111,'v1') IF NOT EXISTS;
-- b
UPDATE spike.resources SET version_id=2, write_id=22222222-2222-2222-2222-222222222222 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p1' IF version_id = 1 AND deleted_at = null;
UPDATE spike.resources SET version_id=2, write_id=22222222-2222-2222-2222-222222222222 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p1' IF version_id = 1 AND deleted_at = null;
-- c
UPDATE spike.resources SET deleted_at = toTimestamp(now()), version_id = 3 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p1' IF version_id = 2 AND deleted_at = null;
UPDATE spike.resources SET version_id=4 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p1' IF version_id = 3 AND deleted_at = null;
-- d
UPDATE spike.resources SET version_id=2 WHERE tenant_id='t1' AND resource_type='Patient' AND id='missing1' IF version_id = 1;
UPDATE spike.resources SET version_id=2 WHERE tenant_id='t1' AND resource_type='Patient' AND id='missing2' IF deleted_at = null;
SELECT * FROM spike.resources WHERE tenant_id='t1' AND resource_type='Patient' AND id='missing1';
SELECT * FROM spike.resources WHERE tenant_id='t1' AND resource_type='Patient' AND id='missing2';
-- e
UPDATE spike.resources USING TIMESTAMP 1234567890 SET version_id=9 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p1' IF version_id = 3;
INSERT INTO spike.resources (tenant_id,resource_type,id,version_id) VALUES ('t1','Patient','p9',1) IF NOT EXISTS USING TIMESTAMP 1234567890;
-- f
CONSISTENCY LOCAL_SERIAL;
SELECT * FROM spike.resources WHERE tenant_id='t1' AND resource_type='Patient' AND id='p1';
CONSISTENCY LOCAL_QUORUM;
-- g
TRACING ON;
INSERT INTO spike.resources (tenant_id,resource_type,id,version_id,write_id,data) VALUES ('t1','Patient','p2',1,33333333-3333-3333-3333-333333333333,'v1') IF NOT EXISTS;
UPDATE spike.resources SET version_id=2 WHERE tenant_id='t1' AND resource_type='Patient' AND id='p2' IF version_id = 1 AND deleted_at = null;
TRACING OFF;
