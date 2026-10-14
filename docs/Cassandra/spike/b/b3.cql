CONSISTENCY LOCAL_QUORUM;
-- (1) delete@300 then late insert@200
DELETE FROM spike.resources_by_type USING TIMESTAMP 300 WHERE tenant_id='t' AND resource_type='B3' AND last_updated=5000 AND id='k1';
INSERT INTO spike.resources_by_type (tenant_id,resource_type,last_updated,id,version_id) VALUES ('t','B3',5000,'k1',1) USING TIMESTAMP 200;
SELECT * FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='B3';
-- (1b) control: insert@400 after delete@300 resurrects
INSERT INTO spike.resources_by_type (tenant_id,resource_type,last_updated,id,version_id) VALUES ('t','B3',5000,'k1',9) USING TIMESTAMP 400;
SELECT * FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='B3';
-- (2) update with lower timestamp on regular column
INSERT INTO spike.resources_by_type (tenant_id,resource_type,last_updated,id,version_id) VALUES ('t','B3',6000,'k2',2) USING TIMESTAMP 500;
UPDATE spike.resources_by_type USING TIMESTAMP 100 SET version_id=1 WHERE tenant_id='t' AND resource_type='B3' AND last_updated=6000 AND id='k2';
SELECT last_updated,id,version_id,writetime(version_id) FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='B3' AND id='k2' ALLOW FILTERING;
UPDATE spike.resources_by_type USING TIMESTAMP 600 SET version_id=3 WHERE tenant_id='t' AND resource_type='B3' AND last_updated=6000 AND id='k2';
SELECT last_updated,id,version_id,writetime(version_id) FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='B3' AND id='k2' ALLOW FILTERING;
-- (3) explicit null vs omitted column (separate table with several regular columns)
