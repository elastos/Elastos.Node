# Installing Elastos ESC Sidechain

```bash
$ ~/node/node.sh esc init
```

```bash
Finding the latest esc release...
INFO: Latest version: v0.1.4.4
Downloading https://download.elastos.io/elastos-esc/elastos-esc-v0.1.4.4/elastos-esc-v0.1.4.4-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-esc-v0.1.4.4-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/esc/esc' -> '/home/ubuntu/node/esc/esc'
Creating esc keystore...
```

A relatively strong password is required to generate the keystore file (the wallet).

```bash
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving esc keystore password...
Checking esc keystore...
You can input an alternative esc reward address. (ENTER to skip)
? Miner Address: 0x67664860731614d0a193b9d312169dbf007e49eb
0x67664860731614d0a193b9d312169dbf007e49eb
INFO: esc keystore file: /home/dev/node/esc/data/keystore/UTC--2023-05-26T06-47-42.576692650Z--09dd04037e719c6dd3acb0599027aa523e184fe3
INFO: esc keystore password file: /home/dev/.config/elastos/esc.txt
INFO: esc miner address file: /home/dev/node/esc/data/miner_address.txt
OK: esc initialized
```

The reward (miner) address entered here should be a cold address you control, separate from the node's keystore. If a mining side chain is started without a cold reward address it still runs, but prints a prominent warning that block rewards credit the node's local hot account. You can set or change it later with:

```bash
$ ~/node/node.sh reward set 0xYOURCOLDADDRESS
```

The ESC JSON-RPC and WebSocket endpoints bind to `127.0.0.1` (localhost only) and the node does not unlock a signing account for RPC. For remote access use an SSH tunnel or VPN rather than exposing the RPC port. See [SECURITY.md](../../../../SECURITY.md) for details and the full port table.

