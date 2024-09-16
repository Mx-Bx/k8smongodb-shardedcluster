# Run docs

## Configs

kubectl apply -f config-server/config-server-statefulset.yaml

kubectl exec -it config-server-0 -- mongosh --port 27201

rs.initiate({
  _id: "cfgrs",
  configsvr: true,
  members: [
    { _id: 0, host: "config-server-0.config-server:27201" },
    { _id: 1, host: "config-server-1.config-server:27202" },
    { _id: 2, host: "config-server-2.config-server:27203" }
  ]
})

## Shards

kubectl apply -f shards/shard1-statefulset.yaml
kubectl exec -it shard1-0 -- mongosh --port 27301
rs.initiate({
  _id: "shard1rs",
  members: [
    { _id: 0, host: "shard1-0.shard1:27301" },
    { _id: 1, host: "shard1-1.shard1:27302" },
    { _id: 2, host: "shard1-2.shard1:27303" }
  ]
})

kubectl apply -f shards/shard2-statefulset.yaml
kubectl exec -it shard2-0 -- mongosh --port 27401
rs.initiate({
  _id: "shard2rs",
  members: [
    { _id: 0, host: "shard2-0.shard2:27401" },
    { _id: 1, host: "shard2-1.shard2:27402" },
    { _id: 2, host: "shard2-2.shard2:27403" }
  ]
})

kubectl apply -f shards/shard3-statefulset.yaml
kubectl exec -it shard3-0 -- mongosh --port 27501
rs.initiate({
  _id: "shard3rs",
  members: [
    { _id: 0, host: "shard3-0.shard3:27501" },
    { _id: 1, host: "shard3-1.shard3:27502" },
    { _id: 2, host: "shard3-2.shard3:27503" }
  ]
})

kubectl apply -f shards/shard4-statefulset.yaml
kubectl exec -it shard4-0 -- mongosh --port 27601
rs.initiate({
  _id: "shard4rs",
  members: [
    { _id: 0, host: "shard4-0.shard4:27601" },
    { _id: 1, host: "shard4-1.shard4:27602" },
    { _id: 2, host: "shard4-2.shard4:27603" }
  ]
})

## Mongos

kubectl exec -it shard1-0 -- mongosh --port 27301 --eval "db.serverStatus().connections"

kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- mongosh --port 27100

sh.addShard("shard1rs/shard1-0.shard1:27301,shard1-1.shard1:27302")
sh.addShard("shard2rs/shard2-0.shard2:27401,shard2-1.shard2:27402,shard2-2.shard2:27403")
sh.addShard("shard3rs/shard3-0.shard3:27501,shard3-1.shard3:27502,shard3-2.shard3:27503")
sh.addShard("shard4rs/shard4-0.shard4:27601,shard4-1.shard4:27602")

## Case issues

mongosh --host config-server-0.config-server.default.svc.cluster.local:27201
