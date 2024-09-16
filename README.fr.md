# Cluster MongoDB Shardé sur Kubernetes

[![English](https://img.shields.io/badge/lang-en-blue.svg)](README.md) [![Français](https://img.shields.io/badge/lang-fr-blue.svg)](README.fr.md)

Ce dépôt contient la configuration complète pour déployer un cluster MongoDB shardé dans un environnement Kubernetes en utilisant `kind` (Kubernetes in Docker). La configuration inclut plusieurs ensembles de réplicas, des données fragmentées et un routage, tous conçus pour garantir une haute disponibilité, évolutivité et tolérance aux pannes.

## Table des Matières

- [Introduction](#introduction)
- [Prérequis](#prérequis)
- [Architecture](#architecture)
- [Guide d'Installation](#guide-dinstallation)
  - [1. Cloner le Dépôt](#1-cloner-le-dépôt)
  - [2. Déployer le Cluster Kubernetes](#2-déployer-le-cluster-kubernetes)
  - [3. Configurer les Shards MongoDB](#3-configurer-les-shards-mongodb)
  - [4. Configurer le Sharding](#4-configurer-le-sharding)
  - [5. Vérifier l'Installation](#5-vérifier-linstallation)
- [Mise à l'Échelle et Test de Charge](#mise-à-léchelle-et-test-de-charge)
- [Cas d'Usage: Fragmenter une Collection d'Utilisateurs par `userId`](#cas-dusage-fragmenter-une-collection-dutilisateurs-par-userid)
- [Dépannage](#dépannage)
- [Contribuer](#contribuer)
- [Licence](#licence)

## Introduction

Ce projet montre comment déployer un cluster MongoDB shardé entièrement fonctionnel sur Kubernetes en utilisant des StatefulSets pour les composants MongoDB, y compris les serveurs de configuration, les serveurs shard, et les services de routage mongos.

L'architecture du cluster comprend :

- **4 Shards** avec 2 ou 3 ensembles de réplicas chacun
- **3 Serveurs de configuration** (ensemble de réplicas)
- **1 Serveur de routage MongoS**

Ce projet est idéal pour quiconque cherche à implémenter une base de données distribuée et évolutive dans Kubernetes pour des applications réelles ou à des fins de test.

## Prérequis

Pour installer et déployer ce cluster MongoDB shardé, assurez-vous d'avoir les outils suivants installés :

- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Client MongoDB (mongosh)](https://www.mongodb.com/try/download/shell)

## Architecture

Le cluster est déployé comme suit :

- **Shard 1 :** Ensemble de réplicas avec des instances sur les ports 27301, 27302, 27303
- **Shard 2 :** Ensemble de réplicas avec des instances sur les ports 27401, 27402, 27403
- **Shard 3 :** Ensemble de réplicas avec des instances sur les ports 27501, 27502, 27503
- **Shard 4 :** Ensemble de réplicas avec des instances sur les ports 27601, 27602, 27603
- **Serveurs de configuration :** 3 instances formant un ensemble de réplicas sur les ports 27201, 27202, 27203
- **Routeur MongoS :** Instance sur le port 27100

## Guide d'Installation

### 1. Cloner le Dépôt

```bash
git clone https://github.com/Mx-Bx/k8smongodb-shardedcluster.git
cd k8smongodb-shardedcluster
```

### 2. Déployer le Cluster Kubernetes

Déployez les shards MongoDB et les serveurs de configuration en utilisant les manifests Kubernetes fournis :

```bash
kubectl apply -R -f manifests/.
## OU
./start-all.sh
```

Vérifiez si tout fonctionne correctement :

```bash
./check-status.sh
```

### 3. Configurer les Shards MongoDB

Déployez les shards MongoDB et les serveurs de configuration en utilisant les manifests Kubernetes fournis :

```bash
./init-sharding.sh
```

### 4. Configurer le Sharding

Activez le sharding pour une base de données :

```javascript
sh.enableSharding("dbTest")
```

### 5. Vérifier l'Installation

Pour vérifier que le sharding fonctionne correctement, vérifiez le statut :

```bash
kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- mongosh --eval "sh.status()"
```

## Mise à l'Échelle et Test de Charge

Vous pouvez mettre à l'échelle les ensembles de réplicas ou les shards en modifiant les fichiers de configuration StatefulSet.

Pour tester la charge, envisagez d'utiliser un jeu de données comme [les exemples de MongoDB](https://www.mongodb.com/docs/atlas/sample-data/) ou de générer des données personnalisées en utilisant l'outil [`mongoimport`](https://www.mongodb.com/docs/database-tools/mongoimport/) de MongoDB.

## Cas d'Usage: Fragmenter une Collection d'Utilisateurs par `userId`

### 1. **Activer le Sharding sur une Base de Données**

Commencez par créer une base de données appelée `testdb` et activer le sharding sur celle-ci.

1. Connectez-vous à l'instance `mongos` :

   ```bash
   kubectl exec -it $(kubectl get pods -l app=mongos -o jsonpath="{.items[0].metadata.name}") -- mongosh --port 27100
   ```

2. Activez le sharding sur la base de données `testdb` :

   ```javascript
   use testdb
   sh.enableSharding("testdb")
   ```

### 2. **Créer une Collection avec une Clé de Sharding**

Ensuite, créez une collection appelée `users` et fragmentez-la en fonction du champ `userId`, qui servira de clé de fragmentation.

```javascript
db.createCollection("users")

sh.shardCollection("testdb.users", { "userId": 1 })
## ou
db.users.createIndex({ 'userId': "hashed" })
sh.shardCollection("testdb.users", { 'userId': "hashed" })

## Pour vérifier si les index ont été créés
db.users.getIndexes()
```

### 3. **Générer un Large Jeu de Données**

Ensuite, générez un grand jeu de données d'utilisateurs pour observer le comportement du sharding. Utilisez une boucle simple pour insérer un grand nombre de documents avec des valeurs `userId` qui seront distribuées uniformément entre les shards.

Dans le shell `mongos`, exécutez le script suivant pour insérer 100 000 documents utilisateur :

```javascript
let batch = [];
for (let i = 1; i <= 100000; i++) {
    batch.push({ userId: i, name: "User " + i, age: Math.floor(Math.random() * 50) + 18 });
    if (batch.length === 1000) {  // Insère tous les 1000 documents
        db.users.insertMany(batch);
        batch = [];
    }
}
if (batch.length > 0) {
    db.users.insertMany(batch);  // Insère les documents restants
}
```

Cela insérera 100 000 utilisateurs dans la collection `users` avec des âges aléatoires. Le champ `userId` est utilisé comme clé de sharding, ce qui permet de distribuer les documents entre vos shards.

### 4. **Vérifier la Distribution des Shards**

Une fois le jeu de données inséré, vous pouvez vérifier comment les chunks ont été distribués entre les shards. Utilisez la commande suivante dans le shell `mongos` :

```javascript
db.adminCommand({ balancerStatus: 1 })
```

Cela affichera si le balancer distribue activement des chunks entre les shards.

Ensuite, vous pouvez vérifier la distribution des chunks pour la collection `users` :

```javascript
db.printShardingStatus()
db.users.getShardDistribution()
```

Recherchez la section `testdb.users` dans la sortie, qui affichera la distribution des chunks entre vos shards. Chaque chunk représentera une plage de valeurs `userId`, et vous verrez combien de chunks sont attribués à chaque shard.

### 5. **Tester les Requêtes pour Vérifier le Sharding**

Vous pouvez effectuer quelques requêtes de test pour vérifier comment le sharding affecte les résultats des requêtes.

Par exemple, pour interroger les utilisateurs avec des plages spécifiques de `userId` et voir comment MongoDB les traite à travers les shards :

```javascript
db.users.find({ userId: { $gte: 1000, $lt: 2000 } }).explain("executionStats")
```

La sortie montrera combien de shards ont été impliqués dans la requête.

### Résumé des Étapes

1. **Activer le sharding** sur la base de données `testdb`.
2. **Fragmenter la collection `users`** par `userId`.
3. **Insérer 100 000 utilisateurs** avec des valeurs `userId`.
4. **Vérifier la distribution des chunks** avec `db.printShardingStatus()`.
5. **Exécuter des requêtes** pour observer comment les données sont réparties entre les shards.

## Dépannage

Si vous rencontrez des problèmes, vous pouvez inspecter les journaux des composants MongoDB :

```bash
kubectl logs <nom-du-pod>
```

### Étape 1 : **Déployer un Pod de Test avec des Outils Réseau**

Vous pouvez exécuter un pod simple `busybox` ou `alpine` incluant `telnet` ou `curl`. Voici comment créer un pod de test :

```bash
kubectl run test-network-a --image=busybox --restart=Never -- sh -c "sleep 3600"
```

### Étape 2 : **Exec dans le Pod de Test et Tester la Connectivité**

Une fois que le pod est en cours d'exécution, connectez-vous dedans et testez la connectivité :

```bash
kubectl exec -it test-network-a -- sh
```

Dans le pod, exécutez la commande suivante pour tester la connectivité vers `config-server-2` :

```bash
telnet config-server-2.config-server.default.svc.cluster.local 27201
```

ou

```bash
nc -zv config-server-2.config-server.default.svc.cluster.local 27201
```

Pour les problèmes courants liés au réseau, au stockage persistant ou à la planification des pods, consultez la documentation Kubernetes ou la documentation MongoDB sur le sharding.

## Contribuer

Si vous souhaitez contribuer, n'hésitez pas à soumettre une pull request. Pour les changements majeurs, veuillez ouvrir un ticket pour discuter des modifications avant de les proposer.

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.
