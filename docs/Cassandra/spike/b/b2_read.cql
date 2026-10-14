CONSISTENCY LOCAL_QUORUM;
PAGING OFF;
TRACING ON;
SELECT * FROM spike.resources_by_type WHERE tenant_id='t' AND resource_type='P2';
