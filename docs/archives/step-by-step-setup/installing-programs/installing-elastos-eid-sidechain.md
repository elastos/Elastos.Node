# Installing Elastos EID Sidechain

```bash
$ ~/node/node.sh eid init
```

```bash
Finding the latest eid release...
INFO: Latest version: v0.2.0
Downloading https://download.elastos.io/elastos-eid/elastos-eid-v0.2.0/elastos-eid-v0.2.0-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-eid-v0.2.0-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/eid/eid' -> '/home/ubuntu/node/eid/eid'
Creating eid keystore...
```

A relatively strong password is required to generate the keystore file (the wallet).

```bash
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving eid keystore password...
Checking eid keystore...
INFO: eid keystore file: /home/ubuntu/node/eid/data/keystore/UTC--2022-05-23T08-18-28.937920124Z--1fbfe55687e5ffa1fb3f5e0caab1ea1679dabf0d
INFO: eid keystore password file: /home/ubuntu/.config/elastos/eid.txt
OK: eid initialized
```

The EID JSON-RPC and WebSocket endpoints bind to `127.0.0.1` (localhost only) and the node does not unlock a signing account for RPC. For remote access use an SSH tunnel or VPN rather than exposing the RPC port. See [SECURITY.md](../../../../SECURITY.md) for details and the full port table.

