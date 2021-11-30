# Elastos Supernode: Setup and Usage Guide

## 1. Requirements

A new Linux operation system is required to run Elastos Supernode.

- **User**
  - should feel **comfortable with Linux** or similar **POSIX shell environment**
  - has access to the **cloud computing**: [Amazon EC2](https://aws.amazon.com/ec2/), [Microsoft Azure VM](https://azure.microsoft.com/en-us/services/virtual-machines/), [Google Cloud Compute Engine](https://cloud.google.com/compute/)
  - Or has permission to place a server in your **home** or **office** if the room or building has free space, cheap electric supply, and good noise insulation.
- **Public Network**
  - **TCP/IP** the current Internet is required to bootstrap the new one
  - Use the **non-metered connection** to prevent a high usage billing.
- **Server Hardware**
  - **CPU**: **2 cores** or more
  - **RAM**: **16 GB** or more
  - **HDD**: **64 GB** or more
    - A solid-state drive (SSD) is a plus but not a must. A hard drive (HDD) should be OK.
- **Server Software**
  - **OS**: **Ubuntu 20.04 LTS** 64 Bit or newer
    - Use **Ubuntu** because the developer uses macOS and Ubuntu to do the test harness. But it is your freedom of choice of other distributions.
    - **LTS** is better because LTS has a longer product life than the **non-LTS** version. (See [Ubuntu Releases](https://wiki.ubuntu.com/Releases))
    - The script prefers a **freshly installed** OS because it reduces conflicts with the old setup. It is time-consuming to debug such conflicts and do the related support works.
- **Server Security Rules**
  - The following ports need to be accessible from anywhere (0.0.0.0/0). For a cloud server, please modify the inbound rules.

| Program | Protocol and Port Range | Purpose           |
| ------- | ----------------------- | ----------------- |
| ELA     | TCP 20338               | ELA P2P           |
| ELA     | TCP 20339               | ELA DPoS          |
| DID     | TCP 20608               | DID P2P           |
| ESC     | TCP+UDP 20638           | ESC P2P           |
| ESC     | TCP 20639               | ESC DPoS          |
| EID     | TCP+UDP 20648           | EID P2P           |
| EID     | TCP 20649               | EID DPoS          |
| Arbiter | TCP 20538               | Arbiter P2P       |
| Carrier | UDP 3478                | Carrier P2P       |
| Carrier | TCP 33445               | Carrier TCP Relay |
| Carrier | UDP 33445               | Carrier P2P       |

## 2. Install the script

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
ELA Management ($HOME/node)

Avaliable Chains:   all, carrier, ela, did, esc, esc-oracle, eid, eid-oracle, arbiter
Avaliable Commands: start, stop, status, upgrade, init
```

The first argument CHAIN specifies chain (program) name, and the second one, COMMAND specifies the action to perform.

Please be notified that the CHAIN argument is optional. If it is absent, all chains will be issued COMMAND.

## 3. Download and configure programs

The init command will download the prebuilt binary package, extract and place the executables in the right place, and write the config files required.

The init command will process the following programs (chains) in one go.

- Elastos Carrier Bootstrap
- Elastos ELA Mainchain
- Elastos DID Sidechain
- Elastos ESC Sidechain (with ESC Oracle)
- Elastos EID Sidechain (with EID Oracle)
- Elastos Arbiter

```bash
$ ~/node/node.sh init
```

As an alternative, you can also run the init command one by one.

    $ ~/node/node.sh carrier init
    $ ~/node/node.sh ela init
    $ ~/node/node.sh did init
    $ ~/node/node.sh esc init
    $ ~/node/node.sh esc-oracle init
    $ ~/node/node.sh eid init
    $ ~/node/node.sh eid-oracle init
    $ ~/node/node.sh arbiter init

### 3.1 Elastos Carrier Bootstrap

```bash
Finding the latest carrier release...
INFO: Latest version: 6.0.1
Downloading https://download.elastos.org/elastos-carrier/elastos-carrier-6.0.1/elastos-carrier-6.0.1-linux-x86_64.tgz...
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
OK: carrier initialzed
```

### 3.2 Elastos ELA

```bash
Finding the latest ela release...
INFO: Latest version: v0.7.0
Downloading https://download.elastos.org/elastos-ela/elastos-ela-v0.7.0/elastos-ela-v0.7.0-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-ela-v0.7.0-linux-x86_64.tgz...
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
OK: ela initialzed
```

### 3.3 Elastos DID Sidechain

```bash
Finding the latest did release...
INFO: Latest version: v0.3.1
Downloading https://download.elastos.org/elastos-did/elastos-did-v0.3.1/elastos-did-v0.3.1-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-did-v0.3.1-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/did/did' -> '/home/ubuntu/node/did/did'
Creating did config file...
Generating random userpass for did RPC interface...
Please input an ELA address to receive awards.
? PayToAddr: ......
Please input a miner name that will be persisted in the blockchain.
? MinerInfo: The Miner
Updating did config file...
INFO: did config file: /home/ubuntu/node/did/config.json
OK: did initialzed
```

### 3.4 Elastos ESC Sidechain

```bash
Finding the latest esc release...
INFO: Latest version: v0.1.3.2
Downloading https://download.elastos.org/elastos-esc/elastos-esc-v0.1.3.2/elastos-esc-v0.1.3.2-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-esc-v0.1.3.2-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/esc/esc' -> '/home/ubuntu/node/esc/esc'
Creating esc keystore...
Please input a password (ENTER to use a random one)
? Password: 
Generating random password...
Saving esc keystore password...
Checking esc keystore...
INFO: esc keystore file: /home/ubuntu/node/esc/data/keystore/UTC--2021-06-02T01-40-32.704318848Z--21bc5264b191a1277d72710db2bc1c3a9b......
INFO: esc keystore password file: /home/ubuntu/.config/elastos/esc.txt
OK: esc initialized
```

### 3.5 Elastos ESC Sidechain (ESC Oracle Module)

```bash
Finding the latest esc-oracle release...
INFO: Latest version: v0.1.3.4
Downloading https://download.elastos.org/elastos-esc-oracle/elastos-esc-oracle-v0.1.3.4/elastos-esc-oracle-v0.1.3.4.tgz...
###################################################################### 100.0%
Extracting elastos-esc-oracle-v0.1.3.4.tgz...
'/home/ubuntu/node/.node-upload/esc-oracle/checkillegalevidence.js' -> '/home/ubuntu/node/esc/esc-oracle/checkillegalevidence.js'
'/home/ubuntu/node/.node-upload/esc-oracle/common.js' -> '/home/ubuntu/node/esc/esc-oracle/common.js'
'/home/ubuntu/node/.node-upload/esc-oracle/crosschain_oracle.js' -> '/home/ubuntu/node/esc/esc-oracle/crosschain_oracle.js'
'/home/ubuntu/node/.node-upload/esc-oracle/ctrt.js' -> '/home/ubuntu/node/esc/esc-oracle/ctrt.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getblklogs.js' -> '/home/ubuntu/node/esc/esc-oracle/getblklogs.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getblknum.js' -> '/home/ubuntu/node/esc/esc-oracle/getblknum.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getexisttxs.js' -> '/home/ubuntu/node/esc/esc-oracle/getexisttxs.js'
'/home/ubuntu/node/.node-upload/esc-oracle/getillegalevidencebyheight.js' -> '/home/ubuntu/node/esc/esc-oracle/getillegalevidencebyheight.js'
'/home/ubuntu/node/.node-upload/esc-oracle/gettxinfo.js' -> '/home/ubuntu/node/esc/esc-oracle/gettxinfo.js'
'/home/ubuntu/node/.node-upload/esc-oracle/sendrechargetransaction.js' -> '/home/ubuntu/node/esc/esc-oracle/sendrechargetransaction.js'
Downloading https://nodejs.org/download/release/v14.17.0/node-v14.17.0-linux-x64.tar.xz...
###################################################################### 100.0%

+ express@4.17.1
+ web3@1.5.0

OK: esc-oracle initialized
```

### 3.6 Elastos EID Sidechain

```bash
Finding the latest eid release...
INFO: Latest version: v0.1.2
Downloading https://download.elastos.org/elastos-eid/elastos-eid-v0.1.2/elastos-eid-v0.1.2-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-eid-v0.1.2-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/eid/eid' -> '/home/ubuntu/node/eid/eid'
Creating eid keystore...
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving eid keystore password...
Checking eid keystore...
INFO: eid keystore file: /home/ubuntu/node/eid/data/keystore/UTC--2021-07-31T09-59-33.603771823Z--03a9526bc7b653d9ad0a23d8ea78beed40054888
INFO: eid keystore password file: /home/ubuntu/.config/elastos/eid.txt
OK: eid initialized
```

### 3.7 Elastos EID Sidechain (EID Oracle Module)

```bash
Finding the latest eid-oracle release...
INFO: Latest version: v0.1.0
Downloading https://download.elastos.org/elastos-eid-oracle/elastos-eid-oracle-v0.1.0/elastos-eid-oracle-v0.1.0.tgz...
###################################################################### 100.0%
Extracting elastos-eid-oracle-v0.1.0.tgz...
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

+ web3@1.5.0
+ express@4.17.1

OK: eid-oracle initialized
```

### 3.8 Elastos Arbiter

```bash
Finding the latest arbiter release...
INFO: Latest version: v0.2.3
Downloading https://download.elastos.org/elastos-arbiter/elastos-arbiter-v0.2.3/elastos-arbiter-v0.2.3-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-arbiter-v0.2.3-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/arbiter/arbiter' -> '/home/ubuntu/node/arbiter/arbiter'
Creating arbiter config file...
Copying ela keystore...
'/home/ubuntu/node/ela/keystore.dat' -> '/home/ubuntu/node/arbiter/keystore.dat'
Updating arbiter config file...
Generating random userpass for arbiter RPC interface...
Please input an ELA address to receive awards.
? PayToAddr: ......
Updating arbiter config file...
INFO: arbiter config file: /home/ubuntu/node/arbiter/config.json
OK: arbiter initialized
```

### 3.9 Directory Layout

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
│   ├── esc                         # eid program
│   ├── logs                        # eid log files
│   └── eid-oracle                  # eid oracle scripts
│
├── extern
│   └── node-v14.17.0-linux-x64     # nodejs required by oracle script
└── node.sh                         # the operating script
```

## 4. Start programs

The **start** command will start all programs (chains).

```bash
$ ~/node/node.sh start
```

The **status** command will summarize the resources occupied and the current chain state.

```bash
$ ~/node/node.sh status
```

## 5. Future upgrade

### 5.1 Update the script

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

### 5.2 Upgrade programs

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

## A. FAQ

1. Q: The script complains: cannot find jq.
   - A: jq is required to parse json config files. Install it by running the following commands:

```bash
$ sudo apt-get update -y
$ sudo apt-get install -y jq
```

