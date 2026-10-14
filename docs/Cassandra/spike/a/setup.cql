CREATE KEYSPACE IF NOT EXISTS spike WITH replication = {'class':'NetworkTopologyStrategy','helios-dc1':1};
CREATE TABLE IF NOT EXISTS spike.resources (tenant_id text, resource_type text, id text, version_id int, deleted_at timestamp, write_ts bigint, write_id uuid, data text, PRIMARY KEY ((tenant_id, resource_type, id)));
CREATE TABLE IF NOT EXISTS spike.resources_by_type (tenant_id text, resource_type text, last_updated timestamp, id text, version_id int, PRIMARY KEY ((tenant_id, resource_type), last_updated, id)) WITH CLUSTERING ORDER BY (last_updated DESC, id DESC);
