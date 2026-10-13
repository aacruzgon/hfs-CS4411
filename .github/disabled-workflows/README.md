# Disabled workflows

These inherited workflows are outside the Cassandra project scope and are
preserved here for reference. GitHub Actions only loads workflows from
`.github/workflows/`, so the YAML files in this directory do not run.

No workflows are currently active. `ci.yml` and `fhir-benchmark.yml` were
archived as well: every job in them targets `self-hosted` runner labels, and
`ci.yml` also needs a remote Docker host (`DOCKER_HOST` secret) for
testcontainers. This fork has neither, so their jobs queued indefinitely.
Writing CI that runs on GitHub-hosted runners, and adapting the benchmark to
Cassandra/PostgreSQL, remain follow-up work.

`cassandra-integration.yml` is intentionally empty. Implement its triggers and
jobs before moving it into `.github/workflows/`; an empty active workflow would
fail validation.

To restore an inherited workflow, move its YAML file into `.github/workflows/`
and restore any necessary caller jobs or dependencies. Calls from `ci.yml` to
HTS conformance, extended CI, and deployment workflows have been removed.
