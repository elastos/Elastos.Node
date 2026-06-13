# Installing Elastos EID Oracle

```bash
$ ~/node/node.sh eid-oracle init
```

```bash
Finding the latest eid-oracle release...
INFO: Latest version: v0.1.3.2
Downloading https://download.elastos.io/elastos-eid-oracle/elastos-eid-oracle-v0.1.3.2/elastos-eid-oracle-v0.1.3.2.tgz...
###################################################################### 100.0%
Extracting elastos-eid-oracle-v0.1.3.2.tgz...
'/home/ubuntu/node/.node-upload/eid-oracle/checkillegalevidence.js' -> '/home/ubuntu/node/eid-oracle/checkillegalevidence.js'
'/home/ubuntu/node/.node-upload/eid-oracle/common.js' -> '/home/ubuntu/node/eid-oracle/common.js'
'/home/ubuntu/node/.node-upload/eid-oracle/crosschain_eid.js' -> '/home/ubuntu/node/eid-oracle/crosschain_eid.js'
'/home/ubuntu/node/.node-upload/eid-oracle/ctrt.js' -> '/home/ubuntu/node/eid-oracle/ctrt.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getblklogs.js' -> '/home/ubuntu/node/eid-oracle/getblklogs.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getblknum.js' -> '/home/ubuntu/node/eid-oracle/getblknum.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getexisttxs.js' -> '/home/ubuntu/node/eid-oracle/getexisttxs.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getillegalevidencebyheight.js' -> '/home/ubuntu/node/eid-oracle/getillegalevidencebyheight.js'
'/home/ubuntu/node/.node-upload/eid-oracle/gettxinfo.js' -> '/home/ubuntu/node/eid-oracle/gettxinfo.js'
'/home/ubuntu/node/.node-upload/eid-oracle/sendrechargetransaction.js' -> '/home/ubuntu/node/eid-oracle/sendrechargetransaction.js'
...
+ web3@1.7.3
+ express@4.18.1
...
OK: eid-oracle initialized
```

The EID oracle is one of the cross-chain services in the `full` profile. It reaches the EID and ELA nodes over loopback, so its own service port is closed to the internet by the firewall (applied by `node.sh harden`, and automatically during migration and self-update). See [SECURITY.md](../../../../SECURITY.md) for the port table.

