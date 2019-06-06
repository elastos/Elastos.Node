# Elastos.ELA.Supernodes

## Introduction

This project is for elastos supernode management.

## Table of Contents

- [Elastos.ELA.Supernodes](#elastoselasupernodes)
  - [Introduction](#introduction)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
    - [Current Features](#current-features)
    - [Planned Features](#planned-features)
  - [Run](#run)
    - [Fist Deployment](#fist-deployment)
    - [Nodes Operation](#nodes-operation)

## Features

### Current Features

- Deployment
- Operation

### Planned Features

- Update

## Run

### Fist Deployment

If it's the first time to deploy the super node on a new server, you can follow the [elastos_supernode_deployment.md](./docs/elastos_supernode_deployment.md).

You can also use the automatic deployment script to follow the prompts to complete the node deployment.

1. Download the nodes.tar.gz to the folder where you prepare to run supernode.

```bash
wget https://raw.githubusercontent.com/elastos/Elastos.ELA.Supernodes/releases/download/v1.0.1/node.tar.gz .
```

2. Unzip nodes.tar.gz

```bash
tar -zxvf node.tar.gz
```

The following output indicates that the decompression is successful.

```
node/
node/token/
node/token/token
node/token/config.json
node/did/
node/did/did
node/did/config.json
node/node.sh
node/carrier/
node/carrier/bootstrapd.conf
node/carrier/ela-bootstrapd
node/carrier/run/
node/ela/
node/ela/ela
node/ela/ela-cli
node/ela/config.json
```

3. Initialize the parameters for supernode

```bash
cd node
./node.sh init
```

Enter the password to create the keystore.dat and the IP or domain name of the node as prompted.

**You should record the `PUBLIC KEY` and use the public key when you update the Node Public Key on your `elastos wallet`**

```
=== 1. create keystore.dat ===
Please enter your password for keystore.dat:create keystore.dat
ADDRESS                            PUBLIC KEY
---------------------------------- ------------------------------------------------------------------
EfXimFfnNL8Cw5U2xkHYabvnJ5JDQYucA3 0312dba0fab6572d56b6f707866814924efd42354cb740fafc842d79d2c2bcd761
---------------------------------- ------------------------------------------------------------------

=== 2. modify the configuration file ===
Please enter your IP or domain name:www.elastos.org
Initialization successful
```

4. Start supernode

```bash
./node.sh start
```

The following output indicates that the nodes have successfully started:

```
Starting ela...
ela: Running, 29709
Starting did...
did: Running, 29723
Starting token...
token: Running, 29736
Starting carrier...
Elastos bootstrap daemon, version 5.2(20190604)
carrier: Running, 2
```

### Nodes Operation

`/node/node.sh` is the main script for maintaining nodes. You can use this script to complete node initialization, startup, shutdown, and so on.

1. Start all nodes

Start ela, did, token and carrier nodes.

```bash
./node.sh start
```

The following output indicates that the nodes have successfully started

```
Starting ela...
ela: Running, 29709
Starting did...
did: Running, 29723
Starting token...
token: Running, 29736
Starting carrier...
Elastos bootstrap daemon, version 5.2(20190604)
carrier: Running, 2
```

2. Stop all nodes

Stop ela, did, token and carrier nodes.

```bash
./node.sh stop
```

If the nodes end successfully, you will see output similar to the following.

```
Stopping ela...
ela: Stopped
Stopping did...
did: Stopped
Stopping token...
token: Stopped
Stopping carrier...
carrier: Stopped
```

3. Check the status of all nodes

Check node status

```bash
./node.sh status
```

If it is an output similar to the following, it means the node is running normally.

```
ela: Running, 29709
did: Running, 29723
token: Running, 29736
carrier: Running, 2
```

If the output is as follows, it means the node is closed.

```
ela: Stopped
did: Stopped
token: Stopped
carrier: Stopped
```