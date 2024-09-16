#!/bin/bash

kubectl exec -it config-server-0 -- mongosh --port 27201 <<EOF
rs.initiate({
  _id: "cfgrs",
  configsvr: true,
  members: [
    { _id: 0, host: "config-server-0.config-server:27201" },
    { _id: 1, host: "config-server-1.config-server:27202" },
    { _id: 2, host: "config-server-2.config-server:27203" }
  ]
})
EOF


shards=("shard1" "shard2" "shard3" "shard4")
ports=(27301 27401 27501 27601)

for i in "${!shards[@]}"; do
  shard=${shards[$i]}
  port=${ports[$i]}
  
  kubectl exec -it ${shard}-0 -- mongosh --port ${port} <<EOF
rs.initiate({
  _id: "${shard}rs",
  members: [
    { _id: 0, host: "${shard}-0.${shard}:${port}" },
    { _id: 1, host: "${shard}-1.${shard}:$((port+1))" },
    { _id: 2, host: "${shard}-2.${shard}:$((port+2))" }
  ]
})
EOF

done

sleep 10

kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}")  -- mongosh --port 27100 <<EOF
sh.addShard("shard1rs/shard1-0.shard1:27301,shard1-1.shard1:27302")
sh.addShard("shard2rs/shard2-0.shard2:27401,shard2-1.shard2:27402,shard2-2.shard2:27403")
sh.addShard("shard3rs/shard3-0.shard3:27501,shard3-1.shard3:27502,shard3-2.shard3:27503")
sh.addShard("shard4rs/shard4-0.shard4:27601,shard4-1.shard4:27602")
EOF

