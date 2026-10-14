CONSISTENCY LOCAL_QUORUM;
COPY spike.resources_by_type (tenant_id,resource_type,last_updated,id,version_id) FROM '/tmp/rows.csv';
SELECT count(*) FROM spike.resources_by_type WHERE tenant_id='t1' AND resource_type='Observation';
