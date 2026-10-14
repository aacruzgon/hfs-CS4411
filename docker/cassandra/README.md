# Single-node Cassandra

A single Apache Cassandra 5.0 node for the Cassandra persistence backend: local
development, the Cassandra test job, and the benchmarks in
`docs/Cassandra/development-roadmap.md` (item 0.1). The three-node cluster
(item 0.3) and the PostgreSQL benchmark container (item 0.2) are separate
files with the same CPU and memory limits.

## Run

```bash
# 16 and 18 GB laptops (1G heap)
docker compose -f docker/cassandra/docker-compose.yml up -d --wait

# 32 GB machines, and every benchmark that goes in the report (2G heap)
docker compose -f docker/cassandra/docker-compose.yml \
               -f docker/cassandra/docker-compose.heap2g.yml up -d --wait
```

`--wait` returns once CQL answers on `127.0.0.1:9042`. A first boot takes
about 60 seconds on an Apple-silicon laptop and a restart about 16. Data lives
in the `hfs-cassandra_cassandra-data` volume and survives `down`; use
`down -v` to start from an empty node.

```bash
docker compose -f docker/cassandra/docker-compose.yml exec cassandra cqlsh
```

Point clients at `127.0.0.1:9042`, not `localhost`: the port is published on
IPv4 loopback only, and `localhost` can resolve to `::1` first. The node
advertises its container IP as `rpc_address`; with one node a driver learns no
peers and stays on the contact point, but if a driver ever tries to reconnect
to the advertised address, set `CASSANDRA_BROADCAST_RPC_ADDRESS: 127.0.0.1`.

## Recorded configuration

| Setting | Value | Why |
| --- | --- | --- |
| Image | `cassandra:5.0.9-bookworm@sha256:7ee3eda0…34d1` | Newest 5.0 patch; this build was pushed 2026-08-11 for amd64 and arm64. Pinned by digest because the plain `5.0.9` tag was rebuilt on a new base in October. |
| Config file | stock `cassandra.yaml` | `cassandra_latest.yaml` also changes memtables, SSTable format, compaction and storage compatibility; we change only what the design names. |
| `paxos_variant` | `v2` | Two round trips per LWT write instead of four. Set by `entrypoint.sh`, because the image's environment variables cannot set it. |
| `paxos_state_purging` | `legacy` (default) | Safe with `LOCAL_QUORUM` commit consistency. Never switch to `repaired` and back. |
| Snitch, DC, rack | `GossipingPropertyFileSnitch`, `dc1`, `rack1` | The same as the three-node cluster, so one `NetworkTopologyStrategy` map, `{'dc1': N}`, works everywhere |
| Heap | `MAX_HEAP_SIZE` 1G, or 2G with the override | G1 sets `-Xms` equal to `-Xmx`. `HEAP_NEWSIZE` stays unset, because it is ignored under G1. |
| Direct memory | 512M, or 1G with the override | Half the heap. Otherwise `cassandra-env.sh` sizes it from the host's RAM. |
| GC threads | 4 parallel, 4 concurrent | Otherwise `cassandra-env.sh` uses the host's core count, not the CPU limit |
| CPU limit | 4 | Same in both profiles and for PostgreSQL |
| Memory limit | 3 GiB, or 5 GiB with the override; swap disabled | Measured idle resident memory: 1.65 GiB with a 1G heap, 2.6 GiB with a 2G heap. A 1.5 GiB limit is OOM-killed at boot. |
| Defaults left alone | `commitlog_sync: periodic` (10000ms), `batch_size_warn_threshold` 5KiB, `batch_size_fail_threshold` 50KiB, tombstone warn 1000 / fail 100000, `num_tokens` 16, `memtable_allocation_type: heap_buffers` | Recorded so that a benchmark report can state them |

OrbStack or Docker Desktop must give its VM more memory than the container
limit.

## Check that the settings are in effect

```bash
docker compose -f docker/cassandra/docker-compose.yml exec cassandra cqlsh -e "
  SELECT name, value FROM system_views.settings
  WHERE name IN ('paxos_variant', 'paxos_state_purging', 'endpoint_snitch',
                 'batch_size_warn_threshold', 'batch_size_fail_threshold',
                 'commitlog_sync', 'commitlog_sync_period');
  SELECT release_version, data_center, rack FROM system.local;"
```

Expected: `paxos_variant` `v2`, `paxos_state_purging` `legacy`, `5.0.9`, `dc1`,
`rack1`. There is no `nodetool` command for the Paxos variant; the
`system_views.settings` virtual table is the source of truth.
