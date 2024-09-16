# Kubernetes MongoDB Sharded Cluster

[![English](https://img.shields.io/badge/lang-en-blue.svg)](README.md) [![Français](https://img.shields.io/badge/lang-fr-blue.svg)](README.fr.md)

This repository contains the complete setup for a MongoDB sharded cluster deployed on a Kubernetes environment using `kind` (Kubernetes in Docker). The configuration includes multiple replica sets, sharded data, and routing, all designed to achieve high availability, scalability, and fault tolerance.

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Setup Guide](#setup-guide)
  - [1. Cloning the Repository](#1-cloning-the-repository)
  - [2. Deploying the Kubernetes Cluster](#2-deploying-the-kubernetes-cluster)
  - [3. Setting up MongoDB Shards](#3-setting-up-mongodb-shards)
  - [4. Configuring Sharding](#4-configuring-sharding)
  - [5. Verifying the Setup](#5-verifying-the-setup)
- [Scaling and Load Testing](#scaling-and-load-testing)
- [Use Case: Sharding a User Collection by `userId`](#use-case-sharding-a-user-collection-by-userid)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This project demonstrates how to deploy a fully functional MongoDB sharded cluster on Kubernetes using StatefulSets for MongoDB components, including config servers, shard servers, and mongos routing services.

The cluster architecture consists of:

- **4 Shards** with 2 or 3 replica sets each
- **3 Config servers** (replica set)
- **1 MongoS routing server**

The project is ideal for anyone looking to implement a scalable, distributed database in Kubernetes for real-world applications or testing.

## Prerequisites

To set up and deploy this MongoDB sharded cluster, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)
- [MongoDB client (mongosh)](https://www.mongodb.com/try/download/shell)

## Architecture

The cluster is deployed as follows:

- **Shard 1:** Replica set with instances on ports 27301, 27302, 27303
- **Shard 2:** Replica set with instances on ports 27401, 27402, 27403
- **Shard 3:** Replica set with instances on ports 27501, 27502, 27503
- **Shard 4:** Replica set with instances on ports 27601, 27602, 27603
- **Config servers:** 3 instances forming a replica set on ports 27201, 27202, 27203
- **MongoS router:** Instance on port 27100

## Setup Guide

### 1. Cloning the Repository

```bash
git clone https://github.com/Mx-Bx/k8smongodb-shardedcluster.git
cd k8smongodb-shardedcluster
```

### 2. Deploying the Kubernetes Cluster

Deploy the MongoDB shards and config servers using the provided Kubernetes manifests:

```bash
kubectl apply -R -f manifests/.
## OR
./start-all.sh
```

Verify if everything is running correctly:

```bash
./check-status.sh
```

### 3. Setting up MongoDB Shards

Deploy the MongoDB shards and config servers using the provided Kubernetes manifests:

```bash
./init-sharding.sh
```

### 4. Configuring Sharding

Enable sharding for a database:

```javascript
sh.enableSharding("dbTest")
```

### 5. Verifying the Setup

To verify that the sharding is working correctly, check the status:

```bash
kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- mongosh --eval "sh.status()"
```

## Scaling and Load Testing

You can scale the replica sets or shards by modifying the StatefulSet configuration files.

For load testing, consider using a dataset like [MongoDB's sample datasets](https://www.mongodb.com/docs/atlas/sample-data/) or generate custom data using [MongoDB's `mongoimport`](https://www.mongodb.com/docs/database-tools/mongoimport/) tool.

## Use Case: Sharding a User Collection by `userId`

### 1. **Enable Sharding on a Database**

First, we will create a database called `testdb` and enable sharding on it.

1. Connect to the `mongos` instance:

   ```bash
   kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- mongosh --port 27100
   ```

2. Enable sharding on the `testdb` database:

   ```javascript
   use testdb
   sh.enableSharding("testdb")
   ```

### 2. **Create a Collection with a Shard Key**

Next, we will create a collection called `users` and shard it based on the `userId` field, which will act as our shard key.

```javascript
db.createCollection("users")
sh.shardCollection("testdb.users", { "userId": 1 })
## or
db.users.createIndex({ 'userId': "hashed" })
sh.shardCollection("testdb.users", { 'userId': "hashed" })

## To verify if indexes were created:
db.users.getIndexes()
```

### 3. **Generate a Large Dataset**

Now, we’ll generate a significant dataset of users to observe the sharding behavior. We’ll use a simple loop to insert a large number of documents with `userId` values that will be evenly distributed across shards.

In the `mongos` shell, run the following script to insert 100,000 user documents:

```javascript
let batch = [];
for (let i = 1; i <= 100000; i++) {
    batch.push({ userId: i, name: "User " + i, age: Math.floor(Math.random() * 50) + 18 });
    if (batch.length === 1000) {  // Insert every 1000 documents
        db.users.insertMany(batch);
        batch = [];
    }
}
if (batch.length > 0) {
    db.users.insertMany(batch);  // Insert remaining documents
}
```

This will insert 100,000 users into the `users` collection with random ages. The `userId` field is used as the shard key, which will help distribute the documents across your shards.

### 4. **Check Shard Distribution**

Once the dataset is inserted, you can verify how the chunks have been distributed across the shards. Use the following command in the `mongos` shell:

```javascript
db.adminCommand({ balancerStatus: 1 })
```

This will show whether the balancer is actively distributing chunks across shards.

Next, you can check the chunk distribution for the `users` collection:

```javascript
db.printShardingStatus()
db.users.getShardDistribution()
```

Look for the `testdb.users` section in the output, which will display the chunk distribution across your shards. Each chunk should represent a range of `userId` values, and you should see how many chunks are assigned to each shard.

### 5. **Test Queries to Ensure Sharding Works**

You can perform some test queries to check how sharding affects the query results.

For example, to query users with specific `userId` ranges and see how MongoDB handles it across shards:

```javascript
db.users.find({ userId: { $gte: 1000, $lt: 2000 } }).explain("executionStats")
```

The output will show how many shards were involved in the query.

### Summary of Steps

1. **Enable sharding** on the `testdb` database.
2. **Shard the `users` collection** by `userId`.
3. **Insert 100,000 users** with `userId` values.
4. **Check chunk distribution** using `db.printShardingStatus()`.
5. **Run queries** to observe how the data is distributed across shards.

## Troubleshooting

If

 you run into any issues, you can inspect the logs of MongoDB components:

```bash
kubectl logs <pod-name>
```

### Step 1: **Deploy a Test Pod with Networking Tools**

You can run a simple `busybox` or `alpine` pod that includes `telnet` or `curl`. Here’s how to create a test pod:

```bash
kubectl run test-network-a --image=busybox --restart=Never -- sh -c "sleep 3600"
```

### Step 2: **Exec into the Test Pod and Test Connectivity**

Once the pod is running, exec into it and check connectivity from there:

```bash
kubectl exec -it test-network-a -- sh
```

Inside the pod, run the following command to test connectivity to `config-server-2`:

```bash
telnet config-server-2.config-server.default.svc.cluster.local 27201
```

or

```bash
nc -zv config-server-2.config-server.default.svc.cluster.local 27201
```

For common issues related to networking, persistent storage, or pod scheduling, refer to the Kubernetes documentation or MongoDB sharding documentation.

## Contributing

If you'd like to contribute, feel free to submit a pull request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
