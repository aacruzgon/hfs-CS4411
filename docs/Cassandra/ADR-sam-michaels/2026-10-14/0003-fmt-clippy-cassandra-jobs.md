# ADR-sam-michaels-0003: Item 0.5's fmt, clippy and Cassandra jobs, clippy split in two under a memory cap, and the weekly Docker prune

- **Date:** 2026-10-14
- **Status:** accepted
- **Context:**
    - Roadmap item 0.5 adds three checks to the self-hosted runner:
        - `cargo fmt --all -- --check`;
        - the `CONTRIBUTING.md` clippy command with `-D warnings`;
        - a job that starts the single-node Cassandra and applies the schema, until Step 2 adds `tests/cassandra_tests.rs`.
    - Alan's checklist for 0.5 fixed several points, which this entry does not re-decide:
        - the runner labels, fork guard, `contents: read`, SHA pins and `persist-credentials: false`;
        - no `[skip ci]` (ADR-aacruzgon-0019);
        - the clippy target directory `${{ runner.workspace }}/target/clippy` with a 30 GB cap (ADR-sam-michaels-0002);
        - the Compose project `hfs-cassandra-ci` on host port 59142, cleaned up with `down -v` on CI's project only;
        - a weekly prune of `gh-runner`'s Docker.
    - Four questions were left open:
        - how to lay out the jobs, whose names become required checks;
        - how hard clippy may load the runner, which is also my desktop;
        - how the Cassandra job applies and checks the schema;
        - what the weekly prune removes, and when it runs.
    - **The second question turned out to be the hard one.**
        - **The freeze.** My first local run of the clippy command used cargo's default 24 jobs while a test Cassandra was starting. The load average reached 37, the desktop became unusable, and the machine had to be rebooted. In the same window, `cqlsh` on the host timed out connecting to the healthy container even with a 30 s timeout. On an idle machine the same connection took 0.2 s.
        - **The cause, found in CI.** With `--all-features`, `helios-fhir` holds the generated models for all four FHIR versions, and its library and its test target each need about 12.8 GB to check. `--all-targets` asks for both, and in one command cargo builds them side by side, about 25.6 GB. No job count above 1 avoids that overlap.
- **Decision:**
    - **One workflow, `.github/workflows/fmt-clippy-cassandra.yml`, with four jobs:**

      | Job | What it runs |
      | --- | --- |
      | `cargo fmt --check` | `cargo fmt --all -- --check` |
      | `cargo clippy (helios-fhir)` | `-p helios-fhir --all-targets --all-features`, at `CARGO_BUILD_JOBS=1` |
      | `cargo clippy (workspace)` | `--workspace --exclude helios-fhir --all-targets --all-features --features helios-fhir/skip-r6-download`, at `CARGO_BUILD_JOBS=8`, with `needs: clippy-fhir` |
      | `Cassandra schema (single node)` | starts the node and applies the schema (below) |

        - fmt, the clippy pair and the Cassandra job are independent, so a failure in one still lets the others report.
        - The runner has one executor, so they run one after another anyway.
    - **Clippy is the `CONTRIBUTING.md` command split in two.**
        - **What the pair covers:** the same crates and targets, with the same `-D warnings` and `-A` flags.
        - **Order:** the `helios-fhir` job checks that crate alone, one unit at a time, so its two large units never overlap. The workspace job runs only after it passes.
        - **The extra feature:** an excluded package gets no `--all-features`. The workspace job therefore asks for `helios-fhir/skip-r6-download` explicitly. Without it, `helios-fhir`'s build script downloads R6 examples from build.fhir.org. With it, `helios-fhir`'s features in the workspace job match the full command's (R4, R4B, R5, R6, `xml`, `skip-r6-download`). The only difference is `default`, which only enables R4, and which no code tests for.
        - **Target directory:** both jobs share `target/clippy`, with the reset step and 30 GB cap of ADR-sam-michaels-0002.
        - **Priority:** both run under `nice -n 10`.
        - **Required checks:** under ADR-aacruzgon-0019 the job names `cargo fmt --check`, `cargo clippy (helios-fhir)` and `cargo clippy (workspace)` become required checks on `main`. Both clippy names must be required, because GitHub skips the workspace job when the `helios-fhir` job fails, and a skipped job counts as passing. Renaming any of them means changing the ruleset in the same change.
    - **The runner service is capped at `MemoryMax=20G`, `MemorySwapMax=0`, with `OOMPolicy=continue`,** set in the systemd drop-in `/etc/systemd/system/actions.runner.aacruzgon-hfs-Cassandra-CS4411.sam-7900x.service.d/memory.conf`.
        - Every CI step runs inside that service's cgroup, cargo and rustc included, so a memory spike kills the build instead of pushing the desktop into swap.
        - `OOMPolicy=continue` keeps the runner online when that happens. systemd's default for a service, `stop`, stops the whole unit when the kernel kills any process in it.
        - `gh-runner`'s rootless Docker runs in its own user session (`user@1001.service`), so the Cassandra container is not under this cap. It has its own 3 GiB limit from `docker/cassandra`.
    - **The Cassandra job:**
        - removes any leftover `hfs-cassandra-ci` project first, because a cancelled run skips its clean-up;
        - starts the container with `up -d --wait --wait-timeout 240`;
        - applies the two `.cql` files with the runner's own `cqlsh` through the published host port, `127.0.0.1:59142`, not `docker compose exec`;
        - checks that re-applying `schema.cql` prints nothing and that keyspace `helios` has exactly ten tables, the acceptance checks in `docs/Cassandra/schema/README.md`;
        - prints the container's last 200 log lines on failure;
        - always ends with `down -v` on `hfs-cassandra-ci`.
    - **`runner-docker-prune.yml`** runs `docker system prune --force --volumes` against `gh-runner`'s rootless daemon:
        - **When:** Saturdays at 20:00 UTC, which is 16:00 Eastern in summer time and 15:00 in winter (cron runs in UTC). The rig is usually on then. Manual dispatch is also available.
        - **What goes:** stopped containers, unused networks, dangling images, build cache and anonymous volumes.
        - **What stays:** tagged images, so the pinned `cassandra:5.0.9` image is not downloaded again every week.
        - **Which daemon:** the step refuses to run unless `DOCKER_HOST` is exactly `gh-runner`'s own socket, `unix:///run/user/<uid>/docker.sock` (CodeRabbit on PR #20).
- **Alternatives considered:**
    - **Three workflow files:** lost. They triplicate the trigger, concurrency and environment blocks.
    - **Chaining fmt or the Cassandra job with `needs:`:** lost. A fmt failure would hide whether clippy and the schema pass. Only the clippy pair is chained, because there the order is what keeps memory under the cap.
    - **The `CONTRIBUTING.md` command as one job.** Tried in this order on PR #20, each time against the 20 GB cap:
        - **24 jobs (cargo's default):** lost. It is what froze the rig locally.
        - **12 jobs:** my first choice, for faster CI. The AI had recommended 8. Run 38661209397 reached the cap after about 4.5 minutes, and with systemd's default `OOMPolicy=stop` the whole runner went offline.
        - **8 jobs:** run 38662774109 was killed after 105 s with `could not compile helios-fhir (lib)` and `(lib test)`. The kernel log shows two `clippy-driver` kills, near 10.3 and 10.1 GB resident. My local 8-job run had passed only because it was partly warm, so those two units never overlapped.
        - **8 jobs, then 1 job if that fails:** the AI recommended it and I first chose it. Run 38669779300 passed: the first attempt was killed after about 13.5 minutes, and the retry at 1 job finished in 6 min 19 s, 20 min 26 s in all. It lost to the split. Every cold build would be killed once and throw away its first attempt, the job would be more than twice as slow as the split, and a real lint error would run twice.
        - **4 jobs, or always 1 job:** lost. Like any job count above 1, 4 still overlaps the two large units. 1 job never reaches the cap, but every build, warm ones included, would run serially.
        - **Raising the cap to about 28 GB:** lost. It would leave about 3 GB of the rig's 31 GB for the desktop while those units build, close to the freeze this entry starts from.
    - **Building `helios-fhir` first with a narrower command, then running the full command:** lost. Tested locally on a warm build, `cargo clippy -p helios-fhir --lib --all-features` resolves crate features differently, so cargo rebuilt everything from `proc-macro2` up instead of reusing anything.
    - **No memory limit, or deferring one until a CI run had been measured:** lost. The AI recommended deferring. I chose to add the cap now, so the first CI runs were already protected, and they needed it.
    - **`docker compose exec cassandra cqlsh` inside the container:** lost. The host's `cqlsh`, through the published port, is the same path the backend and its tests will use (`HFS_TEST_CASSANDRA_URL`, ADR-aacruzgon-0020). It is also why `cqlsh` was installed for `gh-runner` (roadmap Step 0). The first two CI runs showed why the published port matters: rootless Docker's `pasta` port driver published nothing on the host, which `exec` would have hidden until Step 2 (ADR-sam-michaels-0004).
    - **Only applying the schema, with no checks:** lost. The two checks cost about a second and catch a statement that silently stops being idempotent, or a table that goes missing.
    - **`docker system prune --all`:** lost. It would delete the pinned Cassandra image every week, costing a download on the next run, for no disk that matters on a 464 GB disk.
    - **A nightly prune:** lost. The clutter comes from CI runs, at most a few a day, and a nightly run would mostly find nothing.
    - **Other weekly times** (Mondays 10:00 Eastern, as first drafted; Sunday evening; a weekday evening): lost to Saturday afternoon, when my rig is usually on.
- **Consequences:**
    - **Cold clippy takes about 8.7 minutes and stays under the cap.** Attempt 2 of run 38672131127, with `target/clippy` emptied first:

      | Job | Crates built | Time (cargo) | Runner memory peak |
      | --- | --- | --- | --- |
      | `cargo clippy (helios-fhir)` | 170 | 4 min 57 s (4 min 51 s) | 14.8 GiB |
      | `cargo clippy (workspace)` | 721 | 3 min 42 s (3 min 35 s) | 17.3 GiB |

      No OOM kill. The peaks are the runner cgroup's `memory.current`, which also counts reclaimable file cache, so the real headroom is somewhat more than 2.7 GiB.
    - **Warm clippy takes seconds.** Attempt 3 of the same run:

      | Job | Crates built | Time (cargo) | Runner memory peak |
      | --- | --- | --- | --- |
      | `cargo clippy (helios-fhir)` | 0 | 6 s (0.14 s) | 4.1 GiB |
      | `cargo clippy (workspace)` | 2 | 15 s (9.8 s) | 5.2 GiB |
    - **`helios-fhir` is checked twice per cold build, never at the same time.**
        - The workspace job builds it again as a dependency (`Compiling helios-fhir` in its log, cold and warm-after-cold). Its feature set differs from the `helios-fhir` job's by `default`, so the two builds cannot be shared.
        - Both builds stay in `target/clippy` without evicting each other, which is why both jobs are warm on the next run.
    - **The workspace job is the one to watch.** It has the smallest margin under the cap: 17.3 GiB at 8 jobs, with one `helios-fhir` build among them. If a future change (new crates, a new FHIR version) pushes it over, the job fails with an OOM kill in the journal and the runner stays online. The fix is fewer jobs in that job (Alan suggested 4 to 6), not a higher cap: a cap near the rig's 31 GB would no longer protect the desktop.
    - **The `helios-fhir` job hides the workspace result while it fails.** That is the cost of the `needs:` order.
    - **The desktop stays usable during CI.** `nice` yields the CPU to me, and the cap bounds CI's memory at 20 of 31 GB.
    - **A host `cqlsh` timeout under heavy load is a known false failure.** On the runner, jobs are serial, so clippy never runs during the Cassandra job. My own work on the desktop can still slow it. The `cqlsh` calls therefore use `--connect-timeout 30 --request-timeout 60`.
    - **Each Cassandra run costs about 60 s of start-up,** with a fresh node and volume every time, so no state leaks between runs.
    - **The prune only runs once merged.** Scheduled workflows run from the default branch, so the first run is the Saturday after merge, or a manual dispatch. In winter time it runs an hour earlier on the clock, because cron does not follow daylight saving.
- **AI involvement:**
    - **Tool and model:** Claude Code, Claude Opus 5.5.
    - **What the AI proposed:**
        - The workflow layout and the job names.
        - Limiting clippy with `nice` and fewer jobs (first 12, then 8 after measuring).
        - Deferring a memory limit.
        - `OOMPolicy=continue`, after the first kill took the runner offline.
        - The 8-then-1 retry.
        - The `helios-fhir/skip-r6-download` feature in Alan's split.
        - Host `cqlsh` over `exec`, and the two schema checks.
        - Removing leftovers before starting, and logs on failure.
        - The prune policy, and a Monday schedule.
    - **What the AI got wrong:**
        - It took a partly warm local run as proof that 8 jobs fits.
        - It dismissed my early suggestion to split clippy into jobs that run one after another, as not avoiding the overlap. Alan's targeted split, which is close to that suggestion, is what worked.
    - **What the human changed:**
        - I reported that my computer became very slow during the AI's first local clippy run, which led to limiting clippy's jobs and priority.
        - I held the pull request until I had reviewed this entry.
        - I chose 12 jobs over the measured 8, then went back to 8 when 12 was killed at the cap.
        - I chose to add the 20 GB memory cap at once instead of deferring it.
        - I moved the prune to Saturday afternoon, when my rig is usually on.
        - I asked whether clippy could be split into jobs that run one after another.
        - When Alan proposed the split on PR #20, I chose it over the retry that had already passed.
        - I approved the rest of the design as drafted.
    - **What Alan changed:** on PR #20 he diagnosed the overlap of `helios-fhir`'s two units, proposed the two-job split with `needs:`, and asked for both clippy jobs to be required checks.
    - **What was verified and how:**
        - **fmt:** `cargo fmt --all -- --check` passes on `main` at `51c99dd1f`.
        - **The split:** `cargo tree -e features -i helios-fhir`, for the full command and for the workspace job with and without `helios-fhir/skip-r6-download`. Without the feature it is missing; with it, everything but `default` matches.
        - **The CI runs:**
            - each attempt's job times, and the crates each job built (its `Checking` and `Compiling` lines), come from the job logs;
            - the memory peaks come from sampling the runner cgroup's `memory.current` every 2 s, windowed by each job's start and end time;
            - "no OOM kill" comes from the cgroup's `memory.events`, whose `oom_kill` stayed at the 1 left by the retry run;
            - neither split run downloaded R6 data.
        - **The earlier failures:**
            - the runner service's journal ("The kernel OOM killer killed some processes in this unit"; "Failed with result 'oom-kill'" before `OOMPolicy=continue`);
            - the kernel's `Memory cgroup out of memory: Killed process … (clippy-driver)` lines, all with `CONSTRAINT_MEMCG`, which confirms the cap held them to the runner's cgroup.
        - **The Cassandra job:**
            - its run steps were extracted from the workflow and run unchanged against my own Docker first;
            - since run 38669779300 it has passed on the runner, through `127.0.0.1:59142`;
            - `cqlsh` exits 2 on a bad statement in both `-f` and `-e` modes, so a schema error fails the step.
        - **The memory cap:** `systemctl show` on the runner service reports `MemoryMax=21474836480`, `MemorySwapMax=0` and `OOMPolicy=continue`.
        - **Linting:** `zizmor` 1.30.1 reports no findings for the three workflows.
- **Links:**
    - Roadmap item 0.5 and Step 0.
    - ADR-aacruzgon-0018, 0019 and 0020; ADR-sam-michaels-0001, 0002 and 0004.
    - `.github/workflows/fmt-clippy-cassandra.yml` and `.github/workflows/runner-docker-prune.yml`.
    - `docs/Cassandra/schema/README.md`.
    - PR #20:
        - runs 38661209397 (12 jobs) and 38662774109 (8 jobs), killed at the cap;
        - run 38669779300 (retry);
        - run 38672131127 (split, attempts 1 to 3).
