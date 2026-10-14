#!/bin/bash
# usage: run.sh <label> <resource_type>
export CASSANDRA_HOST_PORT=59045
S="$(cd "$(dirname "$0")" && pwd)"
cd "$(git -C "$S" rev-parse --show-toplevel)"
L=$1; RT=$2; IMG=cassandra:5.0.9-trixie@sha256:618a493bcf1f817ea2f07288a46fa76fb2d9c4dfd5a04c28227336405782889c; CF=docker/cassandra/docker-compose.yml
cql(){ docker exec spike-c-cassandra-1 cqlsh -e "$1"; }
echo "== $L start $(date -u +%FT%T)"
cql "CREATE KEYSPACE IF NOT EXISTS spike WITH replication={'class':'NetworkTopologyStrategy','helios-dc1':1}; CREATE TABLE IF NOT EXISTS spike.resources (tenant_id text, resource_type text, id text, version_id int, data text, PRIMARY KEY ((tenant_id, resource_type, id)));"
rm -f $S/ack_$L.txt; touch $S/ack_$L.txt
docker rm -f spike-c-client >/dev/null 2>&1
docker run -d --name spike-c-client --network spike-c_default -v "$S":/w --entrypoint python3 $IMG /w/client.py $RT /w/ack_$L.txt >/dev/null
sleep 30
docker kill -s KILL spike-c-cassandra-1 >/dev/null; echo "KILLED at $(date -u +%FT%T) epoch_ms=$(python3 -c 'import time;print(int(time.time()*1000))')"
sleep 3
docker logs spike-c-client 2>&1 | tail -3
docker rm -f spike-c-client >/dev/null
echo "acks: inserts $(grep -c '^n' $S/ack_$L.txt) updates $(grep -c '^u' $S/ack_$L.txt)"; echo "last lines:"; tail -3 $S/ack_$L.txt
docker compose -p spike-c -f $CF up -d --wait 2>&1 | tail -3
docker logs spike-c-cassandra-1 2>&1 | grep -i 'replay\|commitlog' | tail -12
cql "SELECT id,version_id FROM spike.resources WHERE tenant_id='t' AND resource_type='$RT' ALLOW FILTERING;" > $S/rows_$L.txt
echo rows saved
