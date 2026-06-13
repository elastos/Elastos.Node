# Installing Elastos PG Sidechain

The PG (PGA) chain is an EVM side chain. Install and configure it with:

```bash
$ ~/node/node.sh pg init
```

```bash
Finding the latest pg release...
INFO: Latest version: v0.1.4
Downloading https://download.elastos.io/elastos-pg/elastos-pg-v0.1.4/elastos-pg-v0.1.4-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-pg-v0.1.4-linux-x86_64.tgz...
'/home/ubuntu/node/.node-upload/pg/pg' -> '/home/ubuntu/node/pg/pg'
Creating pg keystore...
```

A relatively strong password is required to generate the keystore file (the wallet).

```bash
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving pg keystore password...
Checking pg keystore...
You can input an alternative pg reward address. (ENTER to skip)
? Miner Address: 0x67664860731614d0a193b9d312169dbf007e49eb
0x67664860731614d0a193b9d312169dbf007e49eb
INFO: pg keystore file: /home/ubuntu/node/pg/data/keystore/UTC--2023-05-26T06-47-42.576692650Z--09dd04037e719c6dd3acb0599027aa523e184fe3
INFO: pg keystore password file: /home/ubuntu/.config/elastos/pg.txt
INFO: pg miner address file: /home/ubuntu/node/pg/data/miner_address.txt
OK: pg initialized
```

The reward (miner) address entered here should be a cold address you control, separate from the node's keystore. If a mining side chain is started without a cold reward address it still runs, but prints a prominent warning that block rewards credit the node's local hot account. You can set or change it later with:

```bash
$ ~/node/node.sh reward set 0xYOURCOLDADDRESS
```

The PG JSON-RPC and WebSocket endpoints bind to `127.0.0.1` (localhost only) and the node does not unlock a signing account for RPC. For remote access use an SSH tunnel or VPN rather than exposing the RPC port. See [SECURITY.md](../../../../SECURITY.md) for details and the full port table.
