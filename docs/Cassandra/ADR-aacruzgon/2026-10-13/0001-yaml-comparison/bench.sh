# usage: bench.sh CFG PROF MODE(B|C)
. $(dirname $0)/lib.sh
cfg=$1; prof=$2; mode=$3; tag=$cfg-$prof; R=$B/raw/$tag; mkdir -p $R
trap cleanup EXIT
boot $cfg $prof || exit 1
echo "$tag ready_secs=$READY_SECS" | tee $R/startup.txt
{
 echo "== $tag verification"
 docker exec $SRV cqlsh -e "SELECT name,value FROM system_views.settings WHERE name IN ('paxos_variant','memtable_allocation_type','storage_compatibility_mode','concurrent_compactors','endpoint_snitch')"
 docker exec $SRV cqlsh -e "SELECT data_center FROM system.local"
 docker exec $SRV cqlsh -e "SELECT name,value FROM system_views.settings WHERE name IN ('commitlog_sync','sstable_format','default_compaction','key_cache_size')" 2>&1
} > $R/verify.txt 2>&1
sleep 60
echo "$tag idle_mem=$(docker stats --no-stream --format '{{.MemUsage}}' $SRV)" | tee $R/idle.txt
SCH="replication(strategy=NetworkTopologyStrategy,dc1=1)"
run3(){ # name, then stress command fn args
  name=$1; shift
  sampler_start $R/$name.mem
  for i in 1 2 3; do "$@" > $R/$name.run$i.txt 2>&1; echo "$tag $name run$i done"; done
  sampler_stop
}
waitcompact(){ docker exec $SRV nodetool flush; while :; do p=$(docker exec $SRV nodetool compactionstats | awk '/pending tasks/{print $3}'); [ "$p" = 0 ] && break; sleep 5; done; }
if [ $mode = B ]; then
  # 1 LWT
  stressp user profile=/lwt-profile.yaml duration=30s no-warmup "ops(insert=1)" cl=LOCAL_QUORUM -rate threads=32 -node $SRV > $R/lwt.warmup.txt 2>&1
  run3 lwt stressp user profile=/lwt-profile.yaml duration=60s no-warmup "ops(insert=1)" cl=LOCAL_QUORUM -rate threads=32 -node $SRV
  { docker exec $SRV nodetool flush; sleep 5; docker exec $SRV nodetool tablestats lwtbench.blogposts; docker exec $SRV nodetool proxyhistograms; } > $R/lwt.tablestats.txt 2>&1
  waitcompact; docker exec $SRV nodetool tablestats lwtbench.blogposts > $R/lwt.tablestats.postcompact.txt 2>&1
  echo "$tag lwt oomkilled=$(docker inspect -f '{{.State.OOMKilled}}' $SRV)" > $R/lwt.oom.txt
  # 2 write
  stress write duration=30s no-warmup cl=LOCAL_QUORUM -rate threads=32 -node $SRV -schema "$SCH" > $R/write.warmup.txt 2>&1
  run3 write stress write duration=60s no-warmup cl=LOCAL_QUORUM -rate threads=32 -node $SRV -schema "$SCH"
  stress write n=1000000 no-warmup cl=LOCAL_QUORUM -rate threads=32 -node $SRV -schema "$SCH" > $R/write.populate.txt 2>&1
  waitcompact; docker exec $SRV nodetool tablestats keyspace1.standard1 > $R/write.tablestats.txt 2>&1
  echo "$tag write oomkilled=$(docker inspect -f '{{.State.OOMKilled}}' $SRV)" > $R/write.oom.txt
  # 3 read
  stress read duration=30s no-warmup cl=LOCAL_QUORUM -rate threads=32 -node $SRV > $R/read.warmup.txt 2>&1
  run3 read stress read duration=60s no-warmup cl=LOCAL_QUORUM -rate threads=32 -node $SRV
  docker exec $SRV nodetool tablestats keyspace1.standard1 > $R/read.tablestats.txt 2>&1
  echo "$tag read oomkilled=$(docker inspect -f '{{.State.OOMKilled}}' $SRV)" > $R/read.oom.txt
else
  sampler_start $R/oom.mem
  stress write duration=60s no-warmup cl=LOCAL_QUORUM -rate threads=32 -node $SRV -schema "$SCH" > $R/oom.write.txt 2>&1
  sampler_stop
  docker exec $SRV nodetool tablestats keyspace1.standard1 > $R/oom.tablestats.txt 2>&1
  echo "$tag oom oomkilled=$(docker inspect -f '{{.State.OOMKilled}}' $SRV) running=$(docker inspect -f '{{.State.Running}}' $SRV)" > $R/oom.oom.txt
fi
echo "$tag FINISHED"
