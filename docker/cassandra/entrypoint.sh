#!/bin/sh
# Wrapper around the official image's docker-entrypoint.sh.
#
# Two steps run before the stock entrypoint:
#
# 1. cassandra_latest.yaml, which 5.0 provides "for new users ... and for users
#    evaluating the technology" (its header; trie memtables, BTI SSTables, UCS
#    compaction, SAI, Paxos v2; see README.md), is copied over cassandra.yaml. It is copied rather than
#    selected with -Dcassandra.config because the stock entrypoint writes
#    CASSANDRA_CLUSTER_NAME, CASSANDRA_ENDPOINT_SNITCH, CASSANDRA_DC and the
#    rest into cassandra.yaml only. The copy runs on every boot, so a restart
#    starts from a fresh file and the stock entrypoint re-applies its edits.
#
# 2. paxos_variant is set explicitly. cassandra_latest.yaml already says v2, so
#    this is an assertion: set_yaml fails the boot if the key is ever missing
#    or changed. The stock entrypoint only rewrites a fixed list of keys, and
#    5.0 ignores JVM system properties for yaml settings unless an
#    undocumented flag is set, so there is no other way to set it.
#
# The files are never bind-mounted, so the stock entrypoint's own edits still
# work.
set -eu

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

cp /etc/cassandra/cassandra_latest.yaml "$yaml"

# Paxos v2: two round trips per LWT write instead of four (cassandra.yaml
# comment, 5.0). The stock cassandra.yaml leaves it at v1. Verify at runtime with
#   SELECT value FROM system_views.settings WHERE name = 'paxos_variant';
set_yaml paxos_variant v2

exec docker-entrypoint.sh "$@"
