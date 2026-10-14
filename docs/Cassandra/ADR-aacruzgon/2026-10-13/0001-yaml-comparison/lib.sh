IMG=cassandra@sha256:618a493bcf1f817ea2f07288a46fa76fb2d9c4dfd5a04c28227336405782889c
B="$(cd "$(dirname "$0")" && pwd)"
SRV=lb-srv; NET=lb-net; VOL=lb-vol
now(){ perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }
cleanup(){ docker rm -f $SRV >/dev/null 2>&1; docker volume rm $VOL >/dev/null 2>&1; docker network rm $NET >/dev/null 2>&1; }
# boot CFG PROFILE ; sets READY_SECS
boot(){
  cfg=$1; prof=$2
  case $prof in P1) heap=1G; dm=512M; lim=3g;; P2) heap=2G; dm=1G; lim=5g;; esac
  cleanup
  docker network create $NET >/dev/null; docker volume create $VOL >/dev/null
  t0=$(now)
  docker run -d --name $SRV --network $NET --cpus 4 --memory $lim --memory-swap $lim \
    -e CASSANDRA_CLUSTER_NAME=helios -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch -e CASSANDRA_DC=dc1 -e CASSANDRA_RACK=rack1 \
    -e MAX_HEAP_SIZE=$heap -e MAX_DIRECT_MEMORY_SIZE=$dm -e "JVM_EXTRA_OPTS=-XX:ParallelGCThreads=4 -XX:ConcGCThreads=4" \
    -v "$B/entrypoint-$cfg.sh":/usr/local/bin/hfs-entrypoint.sh:ro -v $VOL:/var/lib/cassandra \
    --entrypoint sh $IMG /usr/local/bin/hfs-entrypoint.sh cassandra -f >/dev/null
  while :; do
    if docker exec $SRV cqlsh -e "select release_version from system.local" >/dev/null 2>&1; then break; fi
    sleep 2
    [ "$(docker inspect -f '{{.State.Running}}' $SRV)" = true ] || { echo "SERVER DIED"; return 1; }
  done
  READY_SECS=$(perl -e "printf '%.1f', $(now)-$t0")
}
stress(){ # args to cassandra-stress; output to stdout
  docker run --rm --network $NET --cpus 4 --entrypoint /opt/cassandra/tools/bin/cassandra-stress $IMG "$@"
}
stressp(){ docker run --rm --network $NET --cpus 4 -v "$B/lwt-profile.yaml":/lwt-profile.yaml:ro --entrypoint /opt/cassandra/tools/bin/cassandra-stress $IMG "$@"; }
sampler_start(){ ( while :; do echo "$(date +%s) $(docker stats --no-stream --format '{{.MemUsage}}' $SRV)" >> $1; sleep 3; done ) & SAMPLER=$!; }
sampler_stop(){ kill $SAMPLER 2>/dev/null; wait $SAMPLER 2>/dev/null; }
