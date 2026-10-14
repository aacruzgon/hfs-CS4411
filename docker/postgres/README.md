# Single PostgreSQL

A single PostgreSQL 18 instance, the baseline the Cassandra backend is compared
against in `docs/Cassandra/development-roadmap.md` (item 0.2). It runs under the
same CPU and memory limits as `docker/cassandra`, so the two databases are
measured inside the same envelope.

## Run

```bash
# 16 and 18 GB laptops (3 GiB)
docker compose -f docker/postgres/docker-compose.yml up -d --wait

# 32 GB machines, and every benchmark that goes in the report (5 GiB)
docker compose -f docker/postgres/docker-compose.yml \
               -f docker/postgres/docker-compose.mem5g.yml up -d --wait

# Either profile with asynchronous commit (see "Durability" below)
docker compose -f docker/postgres/docker-compose.yml \
               -f docker/postgres/docker-compose.async.yml up -d --wait
```

`--wait` returns once `pg_isready` succeeds, about 6 seconds on a fresh
volume. Data lives in the `hfs-postgres_postgres-data` volume and survives
`down`; use `down -v` to start from an empty database.

Point HFS at it with:

```bash
HFS_STORAGE_BACKEND=postgres \
HFS_DATABASE_URL=postgresql://helios:helios@127.0.0.1:55432/helios \
cargo run --bin hfs --features postgres
```

The container listens on host port **55432**, not 5432. A PostgreSQL installed
on the host and listening on 5432 answers instead of the container without any
error, so HFS or a benchmark would talk to the wrong server. Set `PG_HOST_PORT`
to use another port.

HFS creates its tables and the `pg_trgm` and `btree_gin` extensions itself on
first start. The `helios` user is the database superuser, which is fine for a
local benchmark and must not be copied to a deployment.

```bash
docker compose -f docker/postgres/docker-compose.yml exec postgres psql -U helios
```

## Durability

Both databases can acknowledge a write before it is safely on disk; they
differ in how much they may lose if the machine crashes.

| Setting | Acknowledged | Lost in a crash |
| --- | --- | --- |
| Cassandra, `commitlog_sync: periodic` (10 s) | before the commit log is synced | up to about 10 s; writes block if the last sync is more than 15 s old |
| PostgreSQL `synchronous_commit = on` (default here) | after the commit's WAL is flushed | nothing |
| PostgreSQL `synchronous_commit = off` (`docker-compose.async.yml`) | before the flush | at most 3 x `wal_writer_delay` = 600 ms; never corruption |

The default file runs PostgreSQL at its normal durability. The async override
exists so the benchmarks can also run PostgreSQL the way Cassandra's commit
log behaves, and report the cost of flushing as a measured range. Every
reported number must say which baseline it comes from. See
[ADR-aacruzgon-0005](../../docs/Cassandra/ADR-aacruzgon/2026-10-13/0005-postgres-synchronous-commit.md).

## Recorded configuration

| Setting | Value | Why |
| --- | --- | --- |
| Image | `postgres:18.6-trixie@sha256:74935e72…4336` | PostgreSQL 18.6, Debian 13 trixie (the Cassandra image's base too), amd64 and arm64. 18 is the version this project's own benchmark workflow uses; the persistence test suite keeps its own PostgreSQL 16 containers. Supported until November 2030. |
| `synchronous_commit` | `on`, or `off` with the async override | See "Durability" above |
| `shared_buffers` | 768MB, or 1280MB with the 5 GiB override | 25% of the memory limit, the PostgreSQL docs' starting point |
| `effective_cache_size` | 2GB, or 3584MB | A planner estimate, not an allocation; the 4GB default exceeds the 3 GiB limit |
| `maintenance_work_mem` | 128MB, or 256MB | Index builds during HFS's migrations; the project's benchmark workflow uses 256MB |
| `max_connections` | 200 | HFS opens up to 64 connections per pool (`HFS_PG_MAX_CONNECTIONS`) and may open a second pool for audit |
| `huge_pages` | `off` | The default `try` depends on the host kernel; off makes every machine the same |
| `shared_preload_libraries` | `pg_stat_statements` | Database time per query for the benchmarks; `initdb/` creates the extension on first boot |
| Host port | `127.0.0.1:55432` (`PG_HOST_PORT` overrides) | Avoids a host PostgreSQL on 5432; loopback only. See ADR-aacruzgon-0007. |
| CPU limit | 4 | Same as Cassandra |
| Memory limit | 3 GiB, or 5 GiB with the override; swap disabled | Same as Cassandra (ADR-aacruzgon-0002). Idle: about 53 MiB. |
| `/dev/shm` | 256 MB | Docker's 64 MB default can make parallel queries fail |
| Left at defaults | `fsync` on, `full_page_writes` on, `wal_sync_method` fdatasync, `wal_writer_delay` 200ms, `work_mem` 4MB, `checkpoint_timeout` 5min, `max_wal_size` 1GB, `io_method` worker (new in 18), data checksums on (initdb default in 18) | Recorded so that a benchmark report can state them |

The settings are passed as `-c` flags built from the `PG_*` variables in
`docker-compose.yml`, so each override file changes only environment entries.

## Check that the settings are in effect

```bash
docker compose -f docker/postgres/docker-compose.yml exec postgres psql -U helios -c "
  SELECT name, current_setting(name), source FROM pg_settings
  WHERE name IN ('server_version', 'synchronous_commit', 'shared_buffers',
                 'effective_cache_size', 'maintenance_work_mem', 'max_connections',
                 'huge_pages', 'shared_preload_libraries', 'io_method', 'data_checksums');"
```

Every value set here shows `source = command line`.
