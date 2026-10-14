# ADR-sam-michaels-0002: CI keeps a bounded cargo target directory on the runner instead of using rust-cache

- **Date:** 2026-10-14
- **Status:** accepted
- **Context:**
    - Roadmap Step 0 said to "use `Swatinem/rust-cache` so the FHIR model crates are not rebuilt on every push", and item 0.4 was meant to prove the runner, the toolchain and `rust-cache`.
    - Item 0.4 (PR #17) first shipped with `rust-cache`. On our runner, which is one fixed machine (ADR-sam-michaels-0001), not a fresh hosted VM, it was slow:
        - **Cache miss:** the post-job save uploaded the target directory to GitHub's cache from the rig in 7 min 15 s.
        - **Cache hit:** `rust-cache` deliberately keeps only dependencies and drops workspace crates. The generated FHIR model crate is a workspace crate, so it was rebuilt anyway, and the cache never delivered what the roadmap wanted from it.
    - The roadmap says to use `rust-cache`, so replacing it is a deviation that needs a record.
- **Decision:**
    - **No `rust-cache`.** CI jobs on the self-hosted runner do not use it.
    - **One target directory per job.** Each job keeps its own `CARGO_TARGET_DIR` under `${{ runner.workspace }}/target/<job>`. That is next to the checkout, not inside it, so `actions/checkout`'s `git clean` leaves it alone, and cargo reuses every unchanged crate, the FHIR models included.
    - **No cache for the registry.** The cargo registry already persists in `gh-runner`'s `~/.cargo`.
    - **Bounded by a reset step** that runs before the build and wipes the directory in three cases:
        - **Toolchain change:** the stamp `rustc -V` plus a hash of `Cargo.lock` no longer matches. These are the same moments `rust-cache` would have missed.
        - **Lock-file change:** same stamp check, so each weekly `sync/upstream-*` merge also triggers it.
        - **Over its size cap:** the directory has passed the job's cap.

      A reset costs one cold build.
    - **Caps:**

      | Job | Cap |
      | --- | --- |
      | R4B compile check | 10 GB |
      | 0.5 clippy job (`--all-features`, every FHIR version) | about 30 GB, set in its own PR |

      `/home` on the rig is 464 GB with 437 GB free on 2026-10-14, so the caps together stay a small share of it.
    - **Where the step sets the directory.** The step exports `CARGO_TARGET_DIR` through `$GITHUB_ENV`, because the `runner` context is not available in a job-level `env:`.
    - **`persist-credentials: false` on checkouts.** A persistent workspace would otherwise keep the job token in `.git/config`, where build scripts and proc-macros could read it (CodeRabbit on PR #17).
- **Alternatives considered:**
    - **Keep `rust-cache`:** lost. On this runner it adds a multi-minute upload on every miss, uses GitHub's 10 GB cache quota, and still rebuilds the workspace crates on a hit.
    - **`actions/checkout` with `clean: false` and `target/` inside the checkout:** what the inherited `ci.yml` did. It lost because keeping the source tree dirty between runs means a leftover untracked file can change a build. With the target outside the checkout, the source tree is cleaned on every run and only build output persists.
    - **The inherited `.github/actions/cargo-target-gc`** (`cargo-sweep`, evicting oldest artifacts under a size cap): lost to the reset step.
        - It needs `cargo-sweep` installed on the runner.
        - It assumes `target/` is inside the checkout.
        - It keeps stale artifacts until the cap forces them out.

      The reset step needs nothing installed, and it drops stale artifacts at the moment they go stale.
    - **One target directory shared by all jobs:** lost. Jobs build different feature sets (R4B only here, `--all-features` for clippy), and a shared directory would keep rebuilding the crates whose features differ.
    - **`sccache`:** not needed. A persistent target directory is simpler and already makes an unchanged build nearly free.
- **Consequences:**
    - **Faster.** Alan's table from his review on PR #17, completed with the run that added the reset step:

      | Run | `cargo check` | Whole job |
      | --- | --- | --- |
      | `rust-cache`, cold (run 38627869517, attempt 1) | 73 s | 9 min (7 min 15 s of that is the cache upload) |
      | `rust-cache`, full hit (same run, attempt 2) | 59 s (FHIR crates rebuilt) | 1 min 15 s |
      | Persistent dir, cold (run 38630050973, attempt 1) | 67 s | 69 s |
      | Persistent dir, warm (same run, attempt 2) | 1 s | 3 s |
      | **Persistent dir with reset step, cold** (run 38630825279, attempt 1; reset because no stamp existed) | **66 s** (cargo: 1 min 05 s) | **69 s** |
      | **Persistent dir with reset step, warm** (same run, attempt 2; no reset) | **1 s** (cargo: 0.18 s) | **3 s** |

      After a source change, cargo rebuilds only the changed crates and the crates that depend on them.
    - **Disk is bounded per job, not overall.** CI's total is the sum of the caps, so every new job that compiles Rust must pick a cap and record it here or in its own ADR. Two further limits:
        - **Brief overshoot.** A build can push one directory past its cap until the next run resets it.
        - **The registry is unbounded.** `~/.cargo/registry` is not capped, but it grows in single-digit gigabytes.
    - **A failed or cancelled run can leave a half-written target directory.** Cargo's fingerprints make the next run rebuild whatever is incomplete, so this costs time, not correctness.
    - **Docker images are not covered.** A weekly `docker system prune` for `gh-runner`'s rootless daemon is needed once 0.5 pulls images. That belongs in the 0.5 PR.
    - **The roadmap changes in this commit:**
        - the Step 0 CI bullet replaces `rust-cache` with this decision;
        - the CI-order bullet says 0.4 proves the persistent target directory;
        - row 0.5 says "persistent per-job target directory";
        - row 0.4's evidence cites the final setup.
    - **ADR-aacruzgon-0018 still mentions "the `rust-cache` cache"** in its disk estimate. It is Alan's log, so it is left as it is and this entry supersedes that phrase.
- **AI involvement:**
    - **Tool and model:** Claude Code, Claude Opus 5.5.
    - **What the AI proposed:**
        - The first version of 0.4 with `rust-cache`, as the roadmap and Alan's checklist asked.
        - After measuring it, replacing it with a per-job target directory outside the checkout.
        - `persist-credentials: false`, from CodeRabbit's review.
    - **What the human changed:**
        - I asked to make CI faster because the runner is a fixed machine, and chose to drop `rust-cache` rather than keep both.
        - Alan's review on PR #17 asked for the bound: the stamp-and-cap reset step, the caps, and the timing table above.
        - The AI moved the export from Alan's job-level `env:` to `$GITHUB_ENV`, because the `runner` context is not available there.
    - **What was verified and how:**
        - Step timings and `rust-cache`'s own log lines (`No cache found`, `Cache hit … full match: true`, `Cache up-to-date`) from run 38627869517.
        - The cold and warm timings, and cargo's `Finished … in` lines, from runs 38630050973 and 38630825279.
        - The reset step's `Resetting …` line on the first run of the stamp, and its absence on the second.
        - The free disk, with `df -h /home`.
        - The inherited `cargo-target-gc` action, read for its approach and its assumption that `target/` is inside the checkout.
- **Links:**
    - PR #17 and Alan's review there.
    - Runs https://github.com/aacruzgon/hfs-Cassandra-CS4411/actions/runs/38627869517, https://github.com/aacruzgon/hfs-Cassandra-CS4411/actions/runs/38630050973 and https://github.com/aacruzgon/hfs-Cassandra-CS4411/actions/runs/38630825279.
    - `development-roadmap.md` Step 0 (CI bullet, CI order) and rows 0.4 and 0.5.
    - ADR-aacruzgon-0018; ADR-sam-michaels-0001.
