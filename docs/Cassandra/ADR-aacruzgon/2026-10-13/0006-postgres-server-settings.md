# ADR-aacruzgon-0006: PostgreSQL server settings inside the shared envelope

- **Date:** 2026-10-13
- **Status:** accepted
- **Context:**
    - **The envelope is fixed.** ADR-aacruzgon-0002 gives PostgreSQL the same container limits as Cassandra: 4 CPUs, 3 GiB or 5 GiB, swap off. It leaves to item 0.2 how PostgreSQL uses that space.
    - **The stock image is not sized for it.** Its defaults are sized for a small shared machine (`shared_buffers` 128MB). Its `effective_cache_size` default of 4GB exceeds the 3 GiB limit.
    - **Connections.** HFS opens 16 to 64 connections per pool, and a second pool when audit logging uses PostgreSQL. The default `max_connections` of 100 can therefore run out.
- **Decision:**

    | Setting | 3 GiB profile | 5 GiB profile |
    | --- | --- | --- |
    | `shared_buffers` | 768MB | 1280MB |
    | `effective_cache_size` | 2GB | 3584MB |
    | `maintenance_work_mem` | 128MB | 256MB |
    | `max_connections` | 200 | 200 |
    | `huge_pages` | `off` | `off` |
    | `shared_preload_libraries` | `pg_stat_statements` | `pg_stat_statements` |
    | `/dev/shm` | 256 MB | 256 MB |

    - **`pg_stat_statements`** is created by `initdb/10-pg-stat-statements.sql`.
    - **Left at defaults and recorded:** `work_mem`, checkpoint and WAL sizing, `fsync`, `full_page_writes`, `wal_sync_method` and `io_method`.
    - **Mechanism:** settings are passed as `-c` flags built from `PG_*` environment variables, so the override files change only environment entries.
    - **Login:** user, password and database are all `helios`, matching HFS's `HFS_PG_*` defaults.
- **Alternatives considered:**
    - **The project benchmark workflow's tuning** (`max_connections` 1000, `shared_buffers` 2GB, larger WAL, parallel workers): lost. It is sized for a larger machine than our 3 or 5 GiB envelope.
    - **Stock defaults:** lost. A 4GB cache estimate inside a 3 GiB container misleads the planner, and 128MB of buffers wastes most of the envelope.
    - **Tuning `work_mem`, checkpoints and WAL size now:** lost. There is no measurement yet to justify it. Item 0.6 and the measure-first triggers decide it.
    - **`huge_pages = try`:** lost. Whether it takes effect depends on the host kernel, so machines would differ.
    - **A mounted `postgresql.conf`, or repeating the full command in each override:** lost. The first hides what changed in a long file; the second lets the override files drift from the base file.
- **Consequences:**
    - **Memory at idle** is about 53 MiB of 3 GiB. Under load, `shared_buffers` plus per-connection memory and the page cache must stay within the limit. The item 0.6 harness logs peak memory, as it does for Cassandra.
    - **Host port.** The container listens on host port 55432, not 5432 (ADR-aacruzgon-0007).
    - **The `helios` user is a superuser.** That suits a local benchmark and must not be copied to a deployment.
    - **Checkpoints at the default 5 min / 1GB** may add variance to write-heavy runs. If they do, the benchmark records it rather than this entry pre-empting it.
- **AI involvement:**
    - **Tools:** Claude Code (Opus 5.5), with Sonnet 5.5 subagents.
    - **Research:** the AI read HFS's PostgreSQL connection code (pool size `cores × 4` clamped to 16–64, a second audit pool, `plan_cache_mode` startup options) and the project benchmark workflow's settings. It researched the PostgreSQL docs' guidance (25% of RAM for `shared_buffers`) and the docker-library note on `/dev/shm`.
    - **What the AI proposed:** the values above.
    - **What the human changed:** Alan accepted them as proposed.
    - **Verified:**
        - `pg_settings` shows each value with `source = command line` in both profiles.
        - The container has 4 CPUs, a 3 or 5 GiB limit with swap equal, and a 256 MB `/dev/shm`.
        - The `pg_stat_statements` extension exists after first boot.
        - **HFS end to end:** HFS built with `--features postgres` booted against the container in 53 s, seeding about 1,400 conformance resources. Its migrations created 20 tables and the `pg_trgm` and `btree_gin` extensions with no errors or warnings. `POST /Patient` returned 201 with `ETag: W/"1"`, a read returned `versionId` 1, and an identifier search found the resource.
- **Links:**
    - **Files:** `docker/postgres/`.
    - **Docs:** roadmap items 0.2 and 0.6; ADR-aacruzgon-0002, 0004 and 0005.
