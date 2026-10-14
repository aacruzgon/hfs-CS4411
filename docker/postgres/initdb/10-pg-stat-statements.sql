-- Runs once, on the first boot of an empty data volume, in the "helios"
-- database. The library is preloaded by docker-compose.yml; this makes the
-- pg_stat_statements view available so benchmarks can split database time
-- from Helios time.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
