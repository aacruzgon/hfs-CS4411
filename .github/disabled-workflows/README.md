# Disabled workflows

These inherited workflows are outside the Cassandra project scope and are
preserved here for reference. GitHub Actions only loads workflows from
`.github/workflows/`, so the YAML files in this directory do not run.

The active workflows are `ci.yml` and `fhir-benchmark.yml`. Their existing
resource-intensive configurations are retained for now; slimming CI and
adapting the benchmark to Cassandra/PostgreSQL remain follow-up work.

To restore an inherited workflow, move its YAML file into `.github/workflows/`
and restore any necessary caller jobs or dependencies. Calls from `ci.yml` to
HTS conformance, extended CI, and deployment workflows have been removed.
