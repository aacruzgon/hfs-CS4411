CONSISTENCY LOCAL_QUORUM;
SELECT count(*) FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='P3';
PAGING OFF;
TRACING ON;
SELECT * FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='P3';
