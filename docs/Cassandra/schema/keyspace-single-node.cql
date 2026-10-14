-- Helios Cassandra backend: keyspace for ONE local node (docker/cassandra).
-- DRAFT for the schema session (roadmap Step 1, item 1.1). Not signed off.
--
--   cqlsh -f keyspace-single-node.cql
--   cqlsh -k helios -f schema.cql
--
-- The data-centre name must match the node's GossipingPropertyFileSnitch
-- setting (docker/cassandra: helios-dc1). The three-node cluster (roadmap
-- item 0.3) uses the same CREATE KEYSPACE with 'helios-dc1': 3, and must NOT
-- run the system_traces ALTER below: three nodes satisfy its default RF 2.

CREATE KEYSPACE IF NOT EXISTS helios
    WITH replication = {'class': 'NetworkTopologyStrategy', 'helios-dc1': 1};

-- Single-node setup step, not part of the backend's schema: system_traces
-- defaults to replication factor 2, so fetching a trace at LOCAL_QUORUM
-- fails on one node (spike-findings.md, point 1). The backend never alters
-- system keyspaces; this line is for developers who use TRACING ON.
-- (system_distributed also defaults to RF 3 and system_auth to SimpleStrategy
-- RF 1. Nothing in this project needs either, so they are left alone.)
ALTER KEYSPACE system_traces
    WITH replication = {'class': 'NetworkTopologyStrategy', 'helios-dc1': 1};
