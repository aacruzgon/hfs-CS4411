# ADR-aacruzgon-0022: Every action is pinned to a commit SHA, and the repository requires it

- **Date:** 2026-10-15
- **Status:** accepted
- **Context:**
    - The "Commits and CI" rule in `AGENTS.md` and `CLAUDE.md` asks for every action to be pinned to a full commit SHA, with its version in a comment. Every workflow written for Step 0 follows it (`r4b-compile-check.yml`, `fmt-clippy-cassandra.yml`, `runner-docker-prune.yml`, `upstream-canary.yml`).
    - **`coverage.yml` did not.** Alan added it on 2026-10-13, before the rule, and its five actions used tags: `actions/checkout@v5`, `dtolnay/rust-toolchain@stable`, `taiki-e/install-action@v2`, `actions/upload-artifact@v7` and `codecov/codecov-action@v6`. A tag can be moved to other code at any time by whoever controls the action's repository.
    - **Nothing enforced the rule.** The repository setting "Require actions to be pinned to a full-length commit SHA" was off (`sha_pinning_required: false` in `gh api repos/aacruzgon/hfs-Cassandra-CS4411/actions/permissions`).
    - **Upstream's workflows are not pinned, and most target labels our runners have.** On upstream's `main` (`8aada6230`), none of the `uses:` lines in `.github/workflows` has a SHA, and 68 jobs use `runs-on: [self-hosted, Linux]`, which `sam-7900x` matches. This fork keeps upstream's workflows in `.github/disabled-workflows/`, and git applies upstream's changes to those moved files, but a workflow that is new upstream would arrive live in `.github/workflows/` with the Sunday `sync/upstream-*` merge (roadmap "Track upstream weekly"), without our fork guard.
- **Decision:**
    - **`coverage.yml`'s five actions are pinned** to the commits their tags pointed at on 2026-10-15, each with its version in a comment:

      | Action | Was | Pinned to |
      | --- | --- | --- |
      | `actions/checkout` | `v5` | `fbc6f39…` (v5.1.0) |
      | `dtolnay/rust-toolchain` | `stable` | `e2a55d2…` (master, 2026-10-09, with `toolchain: stable`), the pin the other workflows use |
      | `taiki-e/install-action` | `v2` | `1168f68…` (v2.87.28) |
      | `actions/upload-artifact` | `v7` | `cf430e0…` (v7.0.2) |
      | `codecov/codecov-action` | `v6` | `fb8b358…` (v6.0.2) |

      The versions are unchanged: each SHA is what the tag resolved to, so the workflow behaves as before. Upgrades come through Dependabot's weekly `github-actions` pull requests, which update a SHA pin together with its version comment.
    - **The repository setting "Require actions to be pinned to a full-length commit SHA" is turned on** once this change is on `main` and `coverage.yml` has passed there with the pins. GitHub then fails any job that uses an action by tag or branch, before its steps run.
    - **The Sunday upstream merge checks for new workflows.** Before the `sync/upstream-YYYY-MM-DD` branch merges, any file it adds under `.github/workflows/` is moved to `.github/disabled-workflows/` (roadmap "Track upstream weekly").
- **Alternatives considered:**
    - **Pin `coverage.yml` but leave the setting off:** lost. The rule would still depend on every author and reviewer noticing a tag, and a new upstream workflow would run unchecked.
    - **Turn the setting on first:** lost. `coverage.yml` would fail on every pull request until it was pinned.
    - **Upgrade the actions while pinning them** (for example checkout v5 to v7.0.1, which the other workflows use): lost for this change. Pinning alone keeps the behaviour identical, so a failure afterwards can only come from the setting; upgrades are left to Dependabot.
    - **Restrict "Allowed actions" to a list instead:** not adopted. It would need maintaining for every new action, and pinning already fixes the exact code that runs.
- **Consequences:**
    - **An action's code cannot change under us.** Every job runs the exact commit in its workflow file; only a reviewed pull request, usually from Dependabot, moves a pin.
    - **A new upstream workflow fails at "Set up job" instead of running on the runner,** as long as it uses any action by tag, which every upstream workflow does today. This is a backstop, not a guard: a workflow with only `run:` steps would still run, so the Sunday check for new workflow files is what actually keeps them off the runner.
    - **Writing a workflow takes one more step:** resolving each action's tag to its commit (`git ls-remote --tags https://github.com/<owner>/<action>.git`). A job that forgets fails at once with a clear error, rather than merging unpinned.
    - **The setting also covers actions used inside composite actions.** `codecov/codecov-action` is composite and uses `actions/github-script`, which it already pins (`ed59741…`, v8.0.0); the other four actions use no nested actions.
- **AI involvement:**
    - **Tool and model:** Claude Code (Opus 5.5).
    - **What the AI proposed:** the order (pin, merge, confirm coverage, then the setting); keeping the versions instead of upgrading; using the other workflows' `dtolnay/rust-toolchain` pin; the upstream-workflow reason and the Sunday check for new workflow files.
    - **What the human changed:** the pinning item came from Alan's CI checklist; Alan asked whether it was still needed and approved the plan.
    - **Verified:**
        - Each SHA, from `git ls-remote --tags` on the action's own repository, dereferencing annotated tags; the exact version is the other tag on the same commit.
        - No unpinned `uses:` left in `.github/workflows` or `.github/actions` (`grep` for `uses:` lines without a 40-character SHA).
        - Nested actions, from each pinned commit's `action.yml`.
        - `actionlint` reports nothing for `coverage.yml`.
        - Upstream's pinning and `runs-on` labels, with `git grep` on `upstream/main` (`8aada6230`).
        - The setting before the change, with `gh api repos/aacruzgon/hfs-Cassandra-CS4411/actions/permissions`.
- **Links:**
    - **Docs:** `development-roadmap.md` section 1, "Track upstream weekly" ground rule; the "Commits and CI" section of `AGENTS.md` and `CLAUDE.md`.
    - ADR-aacruzgon-0018; ADR-sam-michaels-0005; `.github/dependabot.yml`.
