# Stock `cassandra.yaml` vs `cassandra_latest.yaml`: indicative comparison

Supporting evidence for [ADR-aacruzgon-0001](../0001-image-pin-and-paxos-v2.md). **Indicative laptop numbers, not the project's benchmarks** (those come from the item 0.6 harness on the designated 32 GB machine).

## Setup

- **Machine:** Apple-silicon laptop, 18 GB RAM, 11 cores, OrbStack with a 9.4 GB VM.
- **Image:** `cassandra@sha256:618a493bcf1f817ea2f07288a46fa76fb2d9c4dfd5a04c28227336405782889c` (`cassandra:5.0.9-trixie`) for both configs.
- **S** = stock `cassandra.yaml`. **L** = `cassandra_latest.yaml`, as shipped.
- **Identical in both:** 4 CPUs, swap off, `GossipingPropertyFileSnitch`, DC `dc1`, `paxos_variant: v2`, GC threads 4, and a fresh volume per boot.
- **P1:** 1G heap, 512M direct memory, 3 GiB limit. **P2:** 2G heap, 1G direct memory, 5 GiB limit.
- **Client:** `cassandra-stress` in a separate container (4 CPUs) on the same Docker network, `-rate threads=32`, `cl=LOCAL_QUORUM`.
- **Runs:** each workload had a 30 s warm-up that was not counted, then three measured 60 s runs.
- **Order:** S-P1, L-P1, S-P2, L-P2, strictly one after the other.
- **Reproduce:** `bash all.sh` (needs Docker and the image). Raw outputs are under `raw/<config>-<profile>/`.

## Startup and idle memory

| Config | Profile | Ready (s) | Idle memory |
| --- | --- | --- | --- |
| S | P1 | 57.7 | 1.558 GiB / 3 GiB |
| L | P1 | 57.9 | 1.610 GiB / 3 GiB |
| S | P2 | 57.2 | 2.584 GiB / 5 GiB |
| L | P2 | 57.3 | 2.648 GiB / 5 GiB |

## Load (P2)

The table shows the median of three runs. Latencies are in ms. No run had errors or an OOM kill.

| Workload | Config | ops/s | ops/s min–max | p50 | p95 | p99 | Peak memory |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LWT | S | 6,235 | 4,745–10,599 | 1.9 | 32.5 | 60.4 | 2.80 GiB |
| LWT | L | 6,883 | 5,805–14,155 | 1.8 | 15.4 | 58.1 | 3.17 GiB |
| Plain write | S | 78,686 | 76,962–81,338 | 0.3 | 0.7 | 1.2 | 2.77 GiB |
| Plain write | L | 98,343 | 95,701–99,883 | 0.3 | 0.6 | 0.9 | 3.30 GiB |
| Read | S | 53,626 | 50,600–55,210 | 0.4 | 1.0 | 2.2 | 2.83 GiB |
| Read | L | 89,305 | 88,988–93,950 | 0.3 | 0.7 | 1.0 | 3.31 GiB |

What exceeds the run-to-run spread:

- **Plain write:** L is about 25% faster, and the two ranges do not overlap.
- **Read:** L is about 67% faster, and the two ranges do not overlap.
- **LWT:** the difference is within the spread. L was ahead in each paired run (by 34%, 10% and 22%). But both configs fell by 55–60% from run 1 to run 3, a trend most likely caused by table growth and compaction, and that drift is larger than the gap between them.
- **Memory:** L's peak was about 0.4–0.5 GiB higher in every workload. It stayed within both limits.

## OOM check (P1, plain write, 60 s, 32 threads)

| Config | ops/s | Peak memory | OOMKilled |
| --- | --- | --- | --- |
| S | 82,736 | 1.62 GiB of 3 GiB | false |
| L | 87,839 | 1.91 GiB of 3 GiB | false |

## Table state after load (P2)

| Table | S live space / SSTables | L live space / SSTables |
| --- | --- | --- |
| LWT `lwtbench.blogposts` (after compaction) | 1.745 GB / 11 | 2.172 GB / 13 |
| Write and read `keyspace1.standard1` | 867.8 MB / 8 | 227.6 MB / 4 |

S compacts with STCS and L with UCS. The 3.8× size gap on `standard1`, the same 1M keys in both, suggests that part of L's read advantage comes from better compaction, not from the file format alone. This comparison was not designed to separate those effects.

## Caveats

- **Shared host:** client and server ran on the same 11-core host alongside other work. Each result is three runs from a single boot, and S always ran before L.
- **The LWT workload only partly resembles ours.** It is from `cqlstress-lwt-example.yaml`: uncontended `INSERT … IF body = NULL` only, with no conditional updates and no logged-batch index writes. `cassandra-stress` cannot set serial consistency, so it used `SERIAL`, which behaves the same as `LOCAL_SERIAL` on a single node.
- **Profile changes from the example:** keyspace `lwtbench` with `{'dc1': 1}`, population 1..2M, cluster `fixed(100)`, and body size 100..1000.
- **Memory sampling:** memory was sampled every 3–5 s, so short peaks can be missed.
