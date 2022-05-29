# 4. Step-by-Step Setup

## 1. Install the script

Login to your server remotely. Normally it is by using an SSH client.

To verify the Linux distribution, you may invoke:

```bash
$ lsb_release -a
$ uname -a
```

Create a folder in your $HOME to hold executable files, config files, and data files.

```bash
$ mkdir ~/node && cd ~/node
```

Download the current version of the script and make it executable.

```bash
$ curl -O https://raw.githubusercontent.com/elastos/Elastos.ELA.Supernode/master/build/skeleton/node.sh
$ chmod a+x node.sh
```

Run the script without any arguments to display the usage.

```bash
$ ~/node/node.sh
```

If the output is similar to the following, then the installation is good.

```bash
Usage: node.sh [CHAIN] COMMAND [OPTIONS]
ELA Management ($HOME/node) [mainnet]

Available Chains:

  ela
  did
  esc
  esc-oracle
  eid
  eid-oracle
  arbiter
  carrier

Available Commands:

  start
  stop
  status
  upgrade [-y] [-n]
  init
  compress_log
```

The first argument CHAIN specifies the chain (program) name, and the second one, COMMAND specifies the action to perform.

Please be notified that the CHAIN argument is optional. If it is absent, all chains will be issued COMMAND.

## 2. Download and configure programs

The init command will download the prebuilt binary package, extract and place the executables in the right place, and write the config files required.

The init command will process the following programs (chains) in one go.

* Elastos Carrier Bootstrap
* Elastos ELA Mainchain
* Elastos DID Sidechain
* Elastos ESC Sidechain (with ESC Oracle)
* Elastos EID Sidechain (with EID Oracle)
* Elastos Arbiter

```bash
$ ~/node/node.sh init
```

As an alternative, you can also run the init command one by one.

```
$ ~/node/node.sh carrier init
$ ~/node/node.sh ela init
$ ~/node/node.sh did init
$ ~/node/node.sh esc init
$ ~/node/node.sh esc-oracle init
$ ~/node/node.sh eid init
$ ~/node/node.sh eid-oracle init
$ ~/node/node.sh arbiter init
```

### 2.1 Elastos Carrier Bootstrap

```bash
Finding the latest carrier release...
INFO: Latest version: 6.0.1
Downloading https://download.elastos.io/elastos-carrier/elastos-carrier-6.0.1/elastos-carrier-6.0.1-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-carrier-6.0.1-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/carrier/usr/bin/ela-bootstrapd' -> '/home/ubuntu/node/carrier/ela-bootstrapd'
Creating carrier config file...
mkdir: created directory '/home/ubuntu/node/carrier/var'
mkdir: created directory '/home/ubuntu/node/carrier/var/lib'
mkdir: created directory '/home/ubuntu/node/carrier/var/lib/ela-bootstrapd'
mkdir: created directory '/home/ubuntu/node/carrier/var/lib/ela-bootstrapd/db'
mkdir: created directory '/home/ubuntu/node/carrier/var/run'
mkdir: created directory '/home/ubuntu/node/carrier/var/run/ela-bootstrapd'
INFO: carrier config file: /home/ubuntu/node/carrier/bootstrapd.conf
OK: carrier initialized
```

### 2.2 Elastos ELA

```bash
Finding the latest ela release...
INFO: Latest version: v0.8.3
Downloading https://download.elastos.io/elastos-ela/elastos-ela-v0.8.3/elastos-ela-v0.8.3-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-ela-v0.8.3-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/ela/ela' -> '/home/ubuntu/node/ela/ela'
'/home/ubuntu/node/.node-upload/ela/ela-cli' -> '/home/ubuntu/node/ela/ela-cli'
Creating ela config file...
Generating random userpass for ela RPC interface...
Updating ela config file...
Creating ela keystore...
Please input a password (ENTER to use a random one)
? Password:
```

A relatively strong password is required to generate the keystore file (the wallet).

```bash
Generating random password...
Saving ela keystore password...
Checking ela keystore...
ADDRESS                            PUBLIC KEY
---------------------------------- ---------------------------------------------------------
EUX2Zz1r9bc6GtCHCD1qWfGEKzuY...... 03af7417cfef028a8138394c5fecb708b40b7dd512381a56a96......
---------------------------------- ---------------------------------------------------------
INFO: ela config file: /home/ubuntu/node/ela/config.json
INFO: ela keystore file: /home/ubuntu/node/ela/keystore.dat
INFO: ela keystore password file: /home/ubuntu/.config/elastos/ela.txt
OK: ela initialized
```

### 2.3 Elastos DID Sidechain

```bash
Finding the latest did release...
INFO: Latest version: v0.3.2
Downloading https://download.elastos.io/elastos-did/elastos-did-v0.3.2/elastos-did-v0.3.2-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-did-v0.3.2-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/did/did' -> '/home/ubuntu/node/did/did'
Creating did config file...
Generating random userpass for did RPC interface...
```

Please enter an address to receive block rewards on the DID sidechain. Here you can enter an address of the ELA main chain copied from Essentials.

```bash
Please input an ELA address to receive awards.
? PayToAddr: ......
```

MinerInfo is the miner's identification, which will be recorded in the block generated by this miner.

```bash
Please input a miner name that will be persisted in the blockchain.
? MinerInfo: The Miner
Updating did config file...
INFO: did config file: /home/ubuntu/node/did/config.json
OK: did initialized
```

### 2.4 Elastos ESC Sidechain

```bash
Finding the latest esc release...
INFO: Latest version: v0.1.4.4
Downloading https://download.elastos.io/elastos-esc/elastos-esc-v0.1.4.4/elastos-esc-v0.1.4.4-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-esc-v0.1.4.4-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/esc/esc' -> '/home/ubuntu/node/esc/esc'
Creating esc keystore...
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving esc keystore password...
Checking esc keystore...
INFO: esc keystore file: /home/ubuntu/node/esc/data/keystore/UTC--2022-05-23T07-17-49.211011226Z--2066fd2b8b1547173886391aece1399c1064b43c
INFO: esc keystore password file: /home/ubuntu/.config/elastos/esc.txt
OK: esc initialized
```

### 2.5 Elastos ESC Sidechain (ESC Oracle Module)

```bash
Finding the latest esc-oracle release...
INFO: Latest version: v0.1.4.4
Downloading https://download.elastos.io/elastos-esc-oracle/elastos-esc-oracle-v0.1.4.4/elastos-esc-oracle-v0.1.4.4.tgz...
###################################################################### 100.0%
Extracting elastos-esc-oracle-v0.1.4.4.tgz...
'/home/ubuntu/node/.node-upload/esc-oracle/checkillegalevidence.js' -> '/home/ubuntu/node/esc/esc-oracle/checkillegalevidence.js'
'/home/ubuntu/node/.node-upload/esc-oracle/common.js' -> '/home/ubuntu/node/esc/esc-oracle/common.js'
'/home/ubuntu/node/.node-upload/esc-oracle/crosschain_oracle.js' -> '/home/ubuntu/node/esc/esc-oracle/crosschain_oracle.js'
'/home/ubuntu/node/.node-upload/esc-oracle/ctrt.js' -> '/home/ubuntu/node/esc/esc-oracle/ctrt.js'
'/home/ubuntu/node/.node-upload/esc-oracle/faileddeposittransactions.js' -> '/home/ubuntu/node/esc/esc-oracle/faileddeposittransactions.js'
'/home/ubuntu/node/.node-upload/esc-oracle/frozen_account.js' -> '/home/ubuntu/node/esc/esc-oracle/frozen_account.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getblklogs.js' -> '/home/ubuntu/node/esc/esc-oracle/getblklogs.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getblknum.js' -> '/home/ubuntu/node/esc/esc-oracle/getblknum.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getexisttxs.js' -> '/home/ubuntu/node/esc/esc-oracle/getexisttxs.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getfaileddeposittransactionbyhash.js' -> '/home/ubuntu/node/esc/esc-oracle/getfaileddeposittransactionbyhash.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getillegalevidencebyheight.js' -> '/home/ubuntu/node/esc/esc-oracle/getillegalevidencebyheight.js'
'/home/ubuntu/node/.node-upload/esc-oracle/gettxinfo.js' -> '/home/ubuntu/node/esc/esc-oracle/gettxinfo.js'
'/home/ubuntu/node/.node-upload/esc-oracle/processedinvalidwithdrawtx.js' -> '/home/ubuntu/node/esc/esc-oracle/processedinvalidwithdrawtx.js'
'/home/ubuntu/node/.node-upload/esc-oracle/receivedInvaliedwithrawtx.js' -> '/home/ubuntu/node/esc/esc-oracle/receivedInvaliedwithrawtx.js'
'/home/ubuntu/node/.node-upload/esc-oracle/sendrechargetransaction.js' -> '/home/ubuntu/node/esc/esc-oracle/sendrechargetransaction.js'
'/home/ubuntu/node/.node-upload/esc-oracle/smallcrosschaintransaction.js' -> '/home/ubuntu/node/esc/esc-oracle/smallcrosschaintransaction.js'
Downloading https://nodejs.org/download/release/v14.17.0/node-v14.17.0-linux-x64.tar.xz...
###################################################################### 100.0%

+ express@4.18.1
+ web3@1.7.3

OK: esc-oracle initialized
```

### 2.6 Elastos EID Sidechain

```bash
Finding the latest eid release...
INFO: Latest version: v0.2.0
Downloading https://download.elastos.io/elastos-eid/elastos-eid-v0.2.0/elastos-eid-v0.2.0-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-eid-v0.2.0-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/eid/eid' -> '/home/ubuntu/node/eid/eid'
Creating eid keystore...
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving eid keystore password...
Checking eid keystore...
INFO: eid keystore file: /home/ubuntu/node/eid/data/keystore/UTC--2022-05-23T08-18-28.937920124Z--1fbfe55687e5ffa1fb3f5e0caab1ea1679dabf0d
INFO: eid keystore password file: /home/ubuntu/.config/elastos/eid.txt
OK: eid initialized
```

### 2.7 Elastos EID Sidechain (EID Oracle Module)

```bash
Finding the latest eid-oracle release...
INFO: Latest version: v0.1.3.2
Downloading https://download.elastos.io/elastos-eid-oracle/elastos-eid-oracle-v0.1.3.2/elastos-eid-oracle-v0.1.3.2.tgz...
###################################################################### 100.0%
Extracting elastos-eid-oracle-v0.1.3.2.tgz...
'/home/ubuntu/node/.node-upload/eid-oracle/checkillegalevidence.js' -> '/home/ubuntu/node/eid/eid-oracle/checkillegalevidence.js'
'/home/ubuntu/node/.node-upload/eid-oracle/common.js' -> '/home/ubuntu/node/eid/eid-oracle/common.js'
'/home/ubuntu/node/.node-upload/eid-oracle/crosschain_eid.js' -> '/home/ubuntu/node/eid/eid-oracle/crosschain_eid.js'
'/home/ubuntu/node/.node-upload/eid-oracle/ctrt.js' -> '/home/ubuntu/node/eid/eid-oracle/ctrt.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getblklogs.js' -> '/home/ubuntu/node/eid/eid-oracle/getblklogs.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getblknum.js' -> '/home/ubuntu/node/eid/eid-oracle/getblknum.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getexisttxs.js' -> '/home/ubuntu/node/eid/eid-oracle/getexisttxs.js'
'/home/ubuntu/node/.node-upload/eid-oracle/getillegalevidencebyheight.js' -> '/home/ubuntu/node/eid/eid-oracle/getillegalevidencebyheight.js'
'/home/ubuntu/node/.node-upload/eid-oracle/gettxinfo.js' -> '/home/ubuntu/node/eid/eid-oracle/gettxinfo.js'
'/home/ubuntu/node/.node-upload/eid-oracle/sendrechargetransaction.js' -> '/home/ubuntu/node/eid/eid-oracle/sendrechargetransaction.js'

+ web3@1.7.3
+ express@4.18.1

OK: eid-oracle initialized
```

### 2.8 Elastos Arbiter

```bash
Finding the latest arbiter release...
INFO: Latest version: v0.3.1
Downloading https://download.elastos.io/elastos-arbiter/elastos-arbiter-v0.3.1/elastos-arbiter-v0.3.1-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-arbiter-v0.3.1-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/arbiter/arbiter' -> '/home/ubuntu/node/arbiter/arbiter'
Creating arbiter config file...
Copying ela keystore...
'/home/ubuntu/node/ela/keystore.dat' -> '/home/ubuntu/node/arbiter/keystore.dat'
Updating arbiter config file...
Generating random userpass for arbiter RPC interface...
```

Please enter an address to receive block rewards on the DID sidechain. Here you can enter an address of the ELA main chain copied from Essentials.

```bash
Please input an ELA address to receive awards.
? PayToAddr: ......
Updating arbiter config file...
INFO: arbiter config file: /home/ubuntu/node/arbiter/config.json
OK: arbiter initialized
```

### 2.9 Directory Layout

Currently, if all things work well, we have the following directory.

```
$ tree -L 2 ~/node
~/node                              # root
├── arbiter                         # arbiter folder
│   ├── arbiter                     # arbiter program
│   ├── config.json                 # arbiter config file
│   ├── ela-cli -> ../ela/ela-cli   # link to ela client program
│   ├── elastos_arbiter             # arbiter running data and logs
│   └── keystore.dat                # keystore file, copied from ela
│
├── carrier                         # carrier bootstrap folder
│   ├── bootstrapd.conf             # config file
│   ├── ela-bootstrapd              # program
│   ├── public-key                  #
│   └── var                         # carrier bootstrap running data
│
├── did                             # did folder
│   ├── config.json                 # did config file
│   ├── did                         # did program
│   └── elastos_did                 # did chain data and log
│
├── ela                             # ela folder
│   ├── config.json                 # ela config file
│   ├── ela                         # ela program
│   ├── ela-cli                     # ela client program, to send commands to ela chain
│   ├── elastos                     # ela chain data and log
│   └── keystore.dat                # ela keystore file, the wallet
│
├── esc                             # esc folder
│   ├── data                        # esc running data and logs
│   ├── esc                         # esc program
│   ├── logs                        # esc log files
│   └── esc-oracle                  # esc oracle scripts
│
├── eid                             # eid folder
│   ├── data                        # eid running data and logs
│   ├── eid                         # eid program
│   ├── logs                        # eid log files
│   └── eid-oracle                  # eid oracle scripts
│
├── extern
│   └── node-v14.17.0-linux-x64     # nodejs required by oracle script
└── node.sh                         # the operating script
```

## 3. Start programs

The **start** command will start all programs (chains).

```bash
$ ~/node/node.sh start
```

The **status** command will summarize the resources occupied and the current chain state.

```bash
$ ~/node/node.sh status
```

## 4. Future upgrade

### 4.1 Update the script

If you had already installed the script several weeks ago, it is better to update to get the latest fixes or features.

```bash
$ ~/node/node.sh script_update
```

It will fetch the latest script from the repository and make it executable.

```bash
Downloading https://raw.githubusercontent.com/elastos/Elastos.ELA.Supernode/master/build/skeleton/node.sh...
###################################################################### 100.0%
OK: $HOME/node/node.sh updated
```

### 4.2 Upgrade programs

We can **upgrade a single program** (chain). For example, to upgrade Elastos ELA, please run the following command.

```bash
$ ~/node/node.sh ela upgrade
```

The script will list all releases from the download server and find the **latest version**.

```bash
Finding the latest ela release...
INFO: Latest version: v0.7.0
```

If you wish to continue, please answer the case-sensitive **Yes**. Any other answers will cancel the operation.

```bash
Proceed upgrade (No/Yes)? Yes
Downloading https://download.elastos.org/elastos-ela/elastos-ela-v0.7.0/elastos-ela-v0.7.0-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-ela-v0.7.0-linux-x86_64.tgz...
```

Then the script will **stop a running program** automatically.

```bash
Stopping ela...
ela v0.7.0: Stopped
```

And replace the files with the updated versions.

```bash
'/home/ubuntu/node/.node-upload/ela/ela' -> '/home/ubuntu/node/ela/ela'
'/home/ubuntu/node/.node-upload/ela/ela-cli' -> '/home/ubuntu/node/ela/ela-cli'
```

If the script has stopped the program before the file replacement, it will **start the program** automatically.

```
Starting ela...
ela v0.7.0: Running
  PID:  405139
  RAM:  857284K
  Uptime: 00:01
  #TCP:  14
  #Files: 35
  #Peers: 3
  Height: 5330
```

Please **check the version** to make sure of a successful program upgrade.
