# Disabled workflows

These inherited workflows are outside the Cassandra project scope and are
preserved here for reference. GitHub Actions only loads workflows from
`.github/workflows/`, so the YAML files in this directory do not run.

Two workflows are active. `.github/workflows/r4b-compile-check.yml` (roadmap
item 0.4) runs on the team's self-hosted runner, `[self-hosted, hfs-cassandra]`
(ADR-aacruzgon-0018, ADR-sam-michaels-0001), and keeps a bounded cargo target
directory on that machine instead of a cache (ADR-sam-michaels-0002).

The standalone `.github/workflows/coverage.yml` workflow runs on standard
GitHub-hosted Linux runners. It measures the default Rust workspace
build (R4 / SQLite), excluding `pysof`, generated FHIR models, and SMTP
integration tests. Optional backend integration coverage is not yet enabled.
It uploads reports to Codecov using the `CODECOV_TOKEN` repository secret
(tokenless for fork PRs); no remote Docker host is needed. Install the
[Codecov GitHub app](https://github.com/apps/codecov) for this repository and
connect it at [Codecov](https://app.codecov.io/gh/aacruzgon/hfs-Cassandra-CS4411) to finish
the service setup. Coverage runs on pushes to `main`, pull requests targeting
`main`, and manual dispatches.

`ci.yml` and `fhir-benchmark.yml` were
archived as well: every job in them targets `self-hosted` runner labels, and
`ci.yml` also needs a remote Docker host (`DOCKER_HOST` secret) for
testcontainers. When they were archived this fork had no self-hosted runner, so
their jobs queued indefinitely. Since #16 it has one, `sam-7900x`
(ADR-sam-michaels-0001), but `ci.yml` still lacks the remote Docker host. Several
`ci.yml` jobs target plain `[self-hosted]` or `[self-hosted, Linux]`, which that
runner matches, so a restored copy must be retargeted to
`[self-hosted, hfs-cassandra]` and given the fork guard from ADR-aacruzgon-0018
first. Follow-up CI, including adapting the benchmark to Cassandra/PostgreSQL,
runs on the self-hosted runner (ADR-aacruzgon-0018).

`cassandra-integration.yml` is intentionally empty. Implement its triggers and
jobs before moving it into `.github/workflows/`; an empty active workflow would
fail validation.

To restore an inherited workflow, move its YAML file into `.github/workflows/`
and restore any necessary caller jobs or dependencies. Calls from `ci.yml` to
HTS conformance, extended CI, and deployment workflows have been removed.
