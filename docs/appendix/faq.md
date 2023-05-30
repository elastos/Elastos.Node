---
description: WIP...
---

# FAQ

## The script complains: cannot find jq

jq is required to parse JSON config files. Install it by running the following commands:

```bash
$ sudo apt-get update -y
$ sudo apt-get install -y jq
```

## Do I need to install all chains or programs?

If you have been elected as a CR Council member, YES.

If you wish to elect a normal BPoS supernode, only ELA is required.

## How to get the public key of a supernode?

Run the command:

```bash
$ ~/node/node.sh ela status
```

Or the primitive commands:

```bash
# Show ELA wallet address and public key
$ cd ~/node/ela
$ cat ~/.config/elastos/ela.txt | ./ela-cli wallet account
```

## How to check the current height of an ELA node?

```bash
$ ~/node/node.sh ela status | grep Height
```

ELA daemon will verify the database when booting, which may take several minutes. The height will be shown as N/A before the verification is completed.

To check the progress of the verification, you can run the following commands:

```bash
$ cd ~/node/ela/elastos/logs/node
$ tail -f *.log | grep 'BLOCKCHAIN INITIALIZE'
[ ========== BLOCKCHAIN INITIALIZE STARTED ========== ]
[ ========== BLOCKCHAIN INITIALIZE FINISHED ========== ]
# CTRL+C to stop
```

## What is PayToAddr?

The miner's ela reward address.

## How to bind this node to the registered BPoS to complete BPoS setup?

To complete the binding between BPoS and the deployed node by updating the nodepublickey for the server node, initiate a BPoS update transaction using Essentials.

For full-page information, click [here](https://www.figma.com/file/JTMd7qytToVaOk2VzwOOcE/Elastos-Essentials).

## How to check the status of a Supernode for a CR Council or BPoS Member's?

* Use the **Essentials** App: for full-page information, click [here](https://www.figma.com/file/JTMd7qytToVaOk2VzwOOcE/Elastos-Essentials).
* Use the **node.sh** script.
  1. Use the latest node.sh script.
  2.  After successful binding of nodepublickey, the name of the registered node and the node status will be displayed.

      ```bash
      $ ~/node/node.sh ela status
      ```
*   Use the [ELA JSON-RPC API](https://github.com/elastos/Elastos.ELA/blob/master/docs/jsonrpc\_apis.md) interface.

    CR Council can access the **listcurrentcrs** interface, while BPoS can access the **listproducers** interface to obtain their respective node information.

## How to re-activate an Inactive ELA Supernode?

Run the command and wait for at least six blocks:

```bash
$ ~/node/node.sh ela activate_bpos
```

Or the underlying primitive commands for references.

```bash
$ cd ~/node/ela
$ ./ela-cli wallet buildtx producer activate --nodepublickey nodepublickey
$ ./ela-cli --rpcuser user123 --rpcpassword pass123 wallet sendtx -f ready_to_send.txn
```

After six blocks, the BPoS supernode will return to Active (or Elected if CRC BPoS supernode). Then after an extra 36-72 blocks, the BPoS supernode normally participates in the consensus work.

## How to check if consensus is normal? How to verify all daemons are working properly?

The consensus of BPoS supernodes generates the ELA main chain. The side chain ESC and EID will dynamically perceive the BPoS supernodes of CR and are responsible for the consensus generation of blocks. All side chain nodes must verify the side chain blocks and reach a consensus.

### ELA

* [x] ELA node height can be synchronized normally and has the highest height.
* [x] The status of the BPoS supernode is obtained by querying the listproducers interface. The node status is Active, which means it is in the active state.
* [x] The status of the BPoS supernode of CR is obtained by querying the listcurrentcrs interface. The node status is Elected, which means it is active.
* [x] CR's BPoS supernode needs to obtain the BPoS supernode of the current consensus, which can be obtained through the getarbiterpeersinfo interface, and the return is empty. Its own CR DPoS supernode does not participate in the consensus.

### DID

* [x] DID node height can be synchronized normally and has the highest height.

### ESC

* [x] ESC node height can be synchronized normally and has the highest height.
* [x] CR's BPoS supernode needs to obtain the ESC node that is on-duty consensus, which can be obtained through the pbft\_getAtbiterPeersInfo interface. If an error is returned, its own ESC node does not participate in the consensus.

### EID

* [x] EID node height can be synchronized normally and has the highest height.
* [x] CR's BPoS supernode needs to obtain the EID node that is on-duty consensus, which can be obtained through the pbft\_getAtbiterPeersInfo interface. If an error is returned, its own EID node does not participate in the consensus.

### Arbiter

* [x] ELA, DID, ESC, EID, ELA SPV heights of Arbiter nodes can be synchronized normally and have the highest height.

## What to do if a chain node is out of sync?

The possible reasons may include:

* [x] **The version is out of date.**

Check versions and issue an [update](../step-by-step-setup/updating-programs.md) if required.

```bash
$ node/node.sh status
```

* [x] **The disk space is not sufficient.**

Check the disk usage and increase it if required.

```bash
$ df -h
```

* [x] **The database is corrupted**.

This error may occur because of abnormal shutting down of the server or daemon processes. It may require purging the database folder to make it synchronize from the very beginning.

| Chain Daemon | Database Directory                                                                                                                                                                                        |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ELA          | `~/node/ela/elastos/data`                                                                                                                                                                                 |
| ESC          | <p><code>~/node/esc/data/geth</code> (without <code>logs</code>)<br><code>~/node/esc/data/header</code><br><code>~/node/esc/data/spv_transaction_info.db</code><br><code>~/node/esc/data/store</code></p> |
| EID          | <p><code>~/node/eid/data/geth</code> (without <code>logs</code>)<br><code>~/node/eid/data/header</code><br><code>~/node/eid/data/spv_transaction_info.db</code><br><code>~/node/eid/data/store</code></p> |
| Arbiter      | `~/node/arbiter/elastos_arbiter/data`                                                                                                                                                                     |

**Warning: be careful about deleting any files on your servers. Consult the developer if you are unsure how to do it, and think twice before the operation.**

Take ELA as an example; you must stop the daemon, purge the database-related folder, and restart it.

```bash
$ ~/node/node.sh ela stop
$ rm -rf ~/node/ela/elastos/data
$ ~/node/node.sh ela start
```

## What to do if a chain daemon is not started?

Check the free memory and disk space:

```bash
$ free -h
$ df -h
```
