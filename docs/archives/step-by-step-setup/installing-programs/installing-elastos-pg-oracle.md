# Installing Elastos PG Oracle

```bash
$ ~/node/node.sh pg-oracle init
```

```bash
Finding the latest pg-oracle release...
INFO: Latest version: v0.1.4
Downloading https://download.elastos.io/elastos-pg-oracle/elastos-pg-oracle-v0.1.4/elastos-pg-oracle-v0.1.4.tgz...
###################################################################### 100.0%
Extracting elastos-pg-oracle-v0.1.4.tgz...
'/home/ubuntu/node/.node-upload/pg-oracle/common.js' -> '/home/ubuntu/node/pg-oracle/common.js'
'/home/ubuntu/node/.node-upload/pg-oracle/crosschain_pg.js' -> '/home/ubuntu/node/pg-oracle/crosschain_pg.js'
'/home/ubuntu/node/.node-upload/pg-oracle/ctrt.js' -> '/home/ubuntu/node/pg-oracle/ctrt.js'
'/home/ubuntu/node/.node-upload/pg-oracle/getblklogs.js' -> '/home/ubuntu/node/pg-oracle/getblklogs.js'
'/home/ubuntu/node/.node-upload/pg-oracle/getblknum.js' -> '/home/ubuntu/node/pg-oracle/getblknum.js'
'/home/ubuntu/node/.node-upload/pg-oracle/getexisttxs.js' -> '/home/ubuntu/node/pg-oracle/getexisttxs.js'
'/home/ubuntu/node/.node-upload/pg-oracle/gettxinfo.js' -> '/home/ubuntu/node/pg-oracle/gettxinfo.js'
'/home/ubuntu/node/.node-upload/pg-oracle/sendrechargetransaction.js' -> '/home/ubuntu/node/pg-oracle/sendrechargetransaction.js'
Downloading https://nodejs.org/download/release/v23.10.0/node-v23.10.0-linux-x64.tar.xz...
###################################################################### 100.0%
...
+ web3@1.7.3
+ express@4.18.1
...
OK: pg-oracle initialized
```

The PG oracle is one of the cross-chain services in the `full` profile. It reaches the PG and ELA nodes over loopback, so its own service port is closed to the internet by the firewall (applied by `node.sh harden`, and automatically during migration and self-update). See [SECURITY.md](../../../../SECURITY.md) for the port table.
