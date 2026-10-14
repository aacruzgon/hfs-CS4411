# ADR log: aacruzgon (Alan Cruz)

This file is Alan Cruz's personal Architecture Decision Record log for the Cassandra backend. One directory per collaborator, `ADR-<github username>/`, holding that person's `ADR-<github username>.md` and any supporting files, so that every design decision made while working with an AI assistant is attributed to the person who drove the session and can be reviewed later.

**Rules**

- Append-only. A decision that is later reversed gets a new entry that supersedes the old one; the old entry's status changes to `superseded by ADR-aacruzgon-NNNN`, and nothing is deleted.
- One entry per decision, numbered sequentially within this file.
- Written by the human, in their own words, at the end of the session in which the decision was made. The AI assistant may draft it, but the human confirms every line before it is committed.
- Only the owner of this file edits it. Another collaborator who disagrees with a decision opens an entry in their own file that references this one.
- The design document (`cassandra-discussion.md`) and the roadmap (`development-roadmap.md`) are updated in the same commit when a decision changes them. The ADR is the record of *why*; those documents are the record of *what*.

**What counts as a decision worth an entry**

A choice between two or more workable designs; a change to a trait surface, table, key, column type or consistency level; a change to the write path, failure handling or the sweeper; a dependency or driver choice; a benchmark methodology choice; anything that deviates from `cassandra-discussion.md` or `development-roadmap.md`; anything the AI proposed that the human rejected or materially altered.

**Entry template** (copy below the index, fill every field, delete none):

```markdown
## ADR-aacruzgon-NNNN: <short title>

- **Date:** YYYY-MM-DD
- **Status:** proposed | accepted | superseded by ADR-<username>-NNNN
- **Context:** what question came up, and what constraint made it a decision rather than a routine change.
- **Decision:** what was decided, in one or two sentences.
- **Alternatives considered:** each alternative and the reason it lost.
- **Consequences:** what becomes easier, what becomes harder, what must be measured or revisited.
- **AI involvement:** tool and model used; what the AI proposed; what the human changed; what was verified and how (code read, test run, spec page, benchmark).
- **Links:** commit, pull request or issue; the section of the design document or roadmap affected.
```

## Index

| ADR | Date | Title | Status |
| --- | --- | --- | --- |
| [0001](#adr-aacruzgon-0001-cassandra-image-pin-and-how-paxos_variant-v2-is-set) | 2026-10-13 | Cassandra image pin and how `paxos_variant: v2` is set | proposed |
| [0002](#adr-aacruzgon-0002-resource-limits-for-the-single-node-container) | 2026-10-13 | Resource limits for the single-node container | proposed |
| [0003](#adr-aacruzgon-0003-snitch-and-data-centre-name-on-the-single-node) | 2026-10-13 | Snitch and data-centre name on the single node | proposed |

## Entries

## ADR-aacruzgon-0001: Cassandra image pin and how `paxos_variant: v2` is set

- **Date:** 2026-10-13
- **Status:** proposed
- **Context:** Roadmap item 0.1 requires a pinned Cassandra 5.0.x and `paxos_variant: v2`. The floating `5.0` tag and the plain `5.0.9` tag were rebuilt on a Debian trixie base on 2026-10-06, so neither is a stable pin. The official image's entrypoint rewrites only a fixed list of `cassandra.yaml` keys from `CASSANDRA_*` variables, and `paxos_variant` is not on that list. In 5.0 the default is v1.
- **Decision:** Pin `cassandra:5.0.9-bookworm@sha256:7ee3eda0f01d80fa4cf93cefb2b1b993bd356a98b7200827d2af5113475534d1` (Cassandra 5.0.9, pushed 2026-08-11, amd64 and arm64). Keep the stock `cassandra.yaml` and set `paxos_variant: v2` from `docker/cassandra/entrypoint.sh`. That wrapper edits the image's own copy of the yaml, fails if the key does not end up on exactly one line, then execs the stock entrypoint. Leave `paxos_state_purging` at its default, `legacy`.
- **Alternatives considered:**
    - `cassandra:5.0.8`, the newest plain tag older than 14 days: lost, because it is an older Cassandra release than the pinned 5.0.9 build, which is itself 63 days old.
    - `cassandra_latest.yaml`, which already sets v2: lost, because it also changes the memtable type, SSTable format, compaction default, key cache and storage compatibility mode, none of which the design asks for, and it moves memtables off-heap.
    - A JVM system property: `-Dcassandra.settings.paxos_variant=v2` was tested and had no effect. The source requires an extra, undocumented `cassandra.config.allow_system_properties=true`.
    - Mounting a full `cassandra.yaml`: lost, because it makes the stock entrypoint's `CASSANDRA_*` edits fail and hides a one-line change in a 2,000-line file.
    - `paxos_state_purging: repaired`: lost, because it needs scheduled Paxos repair and can never be switched back to `legacy`. `legacy` is safe for our `LOCAL_QUORUM` commit consistency.
- **Consequences:** Benchmarks run with v2, which takes two round trips per uncontended LWT write instead of four, and say so. The effective value is checked with `SELECT value FROM system_views.settings WHERE name = 'paxos_variant'`; there is no `nodetool` command for it. The three-node cluster (item 0.3) should reuse the same wrapper. Moving to a newer 5.0.x means updating the digest in `docker-compose.yml` and the README.
- **AI involvement:** Claude Code (Opus 5.5), with Haiku 5.5 and Sonnet 5.5 subagents. The AI listed the Docker Hub tags and digests, read the image's `cassandra.yaml`, `cassandra-env.sh` and `docker-entrypoint.sh`, and read the 5.0 `NEWS.txt` and `Config.java`. It tested four system-property spellings (none worked) and the wrapper (works). It proposed `5.0.9-bookworm` over the subagent's `5.0.8`. Verified on a cold boot from an empty volume and again after `docker compose restart`: `system_views.settings` returned `paxos_variant = v2` and `paxos_state_purging = legacy`. An LWT `INSERT … IF NOT EXISTS` applied, and a stale conditional `UPDATE` returned `[applied] False`. What the human changed: _to be filled in by Alan_.
- **Links:** `docker/cassandra/`; roadmap item 0.1; design document "Consistency levels" paragraph.

## ADR-aacruzgon-0002: Resource limits for the single-node container

- **Date:** 2026-10-13
- **Status:** proposed
- **Context:** Item 0.1 requires an explicit heap and recorded CPU and memory limits, and item 0.2 must give PostgreSQL the same limits, so these numbers become the benchmark envelope. Section 1 of the roadmap fixes the heap per machine: 1G on the 16 and 18 GB laptops, 2G on the 32 GB machines. `cassandra-env.sh` sizes GC threads from the host's `/proc/cpuinfo` and direct memory from the host's RAM, not from the container limits.
- **Decision:**
    - Default profile: 4 CPUs, `MAX_HEAP_SIZE=1G`, `MAX_DIRECT_MEMORY_SIZE=512M`, a 3 GiB memory limit with swap disabled, and `-XX:ParallelGCThreads=4 -XX:ConcGCThreads=4`.
    - `docker-compose.heap2g.yml`, for the 32 GB machines and every reported benchmark, changes only the heap to 2G, direct memory to 1G and the limit to 5 GiB.
- **Alternatives considered:**
    - Limits of 2 GiB and 3 GiB, the smallest that boot: lost. Idle resident memory was 1.65 GiB with a 1G heap and 2.6 GiB with a 2G heap, which leaves too little room under load. A 1.5 GiB limit was OOM-killed at boot.
    - 2 CPUs: lost, because LWT benchmarks at concurrency 32 would be CPU-bound on the database before anything else.
    - Leaving GC threads and direct memory to `cassandra-env.sh`: lost, because both would then vary with the host machine (11 GC threads on this laptop against a 4-CPU limit).
    - Setting limits through environment variables instead of a second file: lost, because the roadmap asks for the limits to be recorded in the file.
- **Consequences:** PostgreSQL in item 0.2 gets 4 CPUs and 3 GiB or 5 GiB with swap disabled. OrbStack or Docker Desktop must allow its VM more than 5 GiB on the benchmark machine. A 1G heap is below the 2 GB minimum in the Cassandra hardware docs, which is acceptable for development but is why reported benchmarks use the 2G profile. If memory pressure appears under benchmark load, revisit the 5 GiB figure before changing the heap.
- **AI involvement:** Claude Code (Opus 5.5), with Sonnet 5.5 subagents. A subagent proposed 3 GiB and 5 GiB from the source defaults (file cache, networking cache, direct memory) and measured resident memory at 1G and 2G heaps. The AI found the host-sized GC-thread and direct-memory logic in `cassandra-env.sh`. Verified: `docker inspect` and the container cgroup show `cpu.max 400000 100000`, `memory.max` 3 GiB and `memory.swap.max 0`. The JVM ran 4 `GC Thread` and 4 `G1 Conc` threads, and `-Xms`/`-Xmx` and `MaxDirectMemorySize` matched each profile. What the human changed: _to be filled in by Alan_.
- **Links:** `docker/cassandra/docker-compose.yml`, `docker/cassandra/docker-compose.heap2g.yml`; roadmap items 0.1, 0.2 and section 1 "Machines".

## ADR-aacruzgon-0003: Snitch and data-centre name on the single node

- **Date:** 2026-10-13
- **Status:** proposed
- **Context:** The Step 1 checklist says the keyspace uses `NetworkTopologyStrategy` with a DC name that matches the Compose files' `GossipingPropertyFileSnitch` setting. The image defaults to `SimpleSnitch` with DC `datacenter1`.
- **Decision:** The single node also runs `GossipingPropertyFileSnitch` with DC `dc1` and rack `rack1`, cluster name `helios`. The keyspace is `{'class': 'NetworkTopologyStrategy', 'dc1': 1}` locally and `'dc1': 3` on the three-node cluster.
- **Alternatives considered:** `SimpleSnitch` on the single node: lost, because the keyspace definition, and therefore `schema.cql` or the backend's `initialize`, would then differ between the single node (`datacenter1`) and the cluster.
- **Consequences:** One DC name across item 0.3, `schema.cql` (item 1.1) and the backend config. `LOCAL_QUORUM` and `LOCAL_SERIAL` resolve against `dc1` everywhere.
- **AI involvement:** Claude Code (Opus 5.5). The AI proposed the name. A subagent verified that `system.local` reports `dc1 | rack1` and that a keyspace with `{'dc1': 1}` accepts LWTs. What the human changed: _to be filled in by Alan_.
- **Links:** `docker/cassandra/docker-compose.yml`; roadmap Step 1 checklist "Keyspace" row; item 0.3.
