#!/bin/sh
set -eu
cp /etc/cassandra/cassandra_latest.yaml /etc/cassandra/cassandra.yaml
yaml=/etc/cassandra/cassandra.yaml

# set_yaml KEY VALUE: set a top-level scalar key, uncommenting it if present,
# appending it if absent, and failing if the result is not exactly one line.
set_yaml() {
    if grep -qE "^#? ?$1:" "$yaml"; then
        sed -i -E "s|^#? ?$1:.*|$1: $2|" "$yaml"
    else
        printf '%s: %s\n' "$1" "$2" >> "$yaml"
    fi
    if [ "$(grep -cE "^$1: $2\$" "$yaml")" -ne 1 ]; then
        echo "entrypoint.sh: failed to set $1: $2 in $yaml" >&2
        exit 1
    fi
}

# Paxos v2: two round trips per LWT write instead of four (cassandra.yaml
# comment, 5.0). The 5.0 default is v1. Verify at runtime with
#   SELECT value FROM system_views.settings WHERE name = 'paxos_variant';
set_yaml paxos_variant v2

exec docker-entrypoint.sh "$@"
