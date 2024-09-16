# Use Case: Sharding a User Collection by `userId`

## 1. **Enable Sharding on a Database**

First, we will create a database called `testdb` and enable sharding on it.

1. Connect to the `mongos` instance:

   ```bash
   kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- mongosh --port 27100
   ```

2. Enable sharding on the `testdb` database:

   ```javascript
   sh.enableSharding("testdb")
   ```

## 2. **Create a Collection with a Shard Key**

Next, we will create a collection called `users` and shard it based on the `userId` field, which will act as our shard key.

```javascript
db.createCollection("users")
sh.shardCollection("testdb.users", { "userId": 1 })
## ou
db.users.createIndex({ 'userId': "hashed" })
sh.shardCollection("testdb.users1", { 'userId': "hashed" })

## Pour verifier si les index ont été créer
db.users.getIndexes()
```

## 3. **Generate a Large Dataset**

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

## 4. **Check Shard Distribution**

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

## 5. **Test Queries to Ensure Sharding Works**

You can perform some test queries to check how sharding affects the query results.

For example, to query users with specific `userId` ranges and see how MongoDB handles it across shards:

```javascript
db.users.find({ userId: { $gte: 1000, $lt: 2000 } }).explain("executionStats")
```

The output will show how many shards were involved in the query.

## Summary of Steps

1. **Enable sharding** on the `testdb` database.
2. **Shard the `users` collection** by `userId`.
3. **Insert 100,000 users** with `userId` values.
4. **Check chunk distribution** using `db.printShardingStatus()`.
5. **Run queries** to observe how the data is distributed across shards.
