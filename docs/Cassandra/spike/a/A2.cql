CONSISTENCY LOCAL_QUORUM;
SERIAL CONSISTENCY LOCAL_SERIAL;
TRACING ON;
SELECT last_updated,id,version_id FROM spike.resources_by_type WHERE tenant_id='t1' AND resource_type='Observation' AND (last_updated, id) < ('2026-01-01 00:41:40+0000', 'obs03501') LIMIT 20;
SELECT count(*) FROM spike.resources_by_type WHERE tenant_id='t1' AND resource_type='Observation';
TRACING OFF;
