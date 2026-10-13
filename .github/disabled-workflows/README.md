# Disabled workflows

These inherited workflows are outside the Cassandra project scope and are
preserved here for reference. GitHub Actions only loads workflows from
`.github/workflows/`, so the YAML files in this directory do not run.

The standalone `.github/workflows/coverage.yml` workflow is active and runs
on standard GitHub-hosted Linux runners. It measures the default Rust workspace
build (R4 / SQLite), excluding `pysof`, generated FHIR models, and SMTP
integration tests. Optional backend integration coverage is not yet enabled.
It uploads reports to Codecov using GitHub OIDC (tokenless for fork PRs), so no
`CODECOV_TOKEN` secret or remote Docker host is needed. Install the
[Codecov GitHub app](https://github.com/apps/codecov) for this repository and
connect it at [Codecov](https://app.codecov.io/gh/aacruzgon/hfs-CS4411) to finish
the service setup. Coverage runs on pushes to `main`, pull requests targeting
`main`, and manual dispatches.

`ci.yml` and `fhir-benchmark.yml` were
archived as well: every job in them targets `self-hosted` runner labels, and
`ci.yml` also needs a remote Docker host (`DOCKER_HOST` secret) for
testcontainers. This fork has neither, so their jobs queued indefinitely.
Broader CI on GitHub-hosted runners, and adapting the benchmark to
Cassandra/PostgreSQL, remain follow-up work.

`cassandra-integration.yml` is intentionally empty. Implement its triggers and
jobs before moving it into `.github/workflows/`; an empty active workflow would
fail validation.

To restore an inherited workflow, move its YAML file into `.github/workflows/`
and restore any necessary caller jobs or dependencies. Calls from `ci.yml` to
HTS conformance, extended CI, and deployment workflows have been removed.
