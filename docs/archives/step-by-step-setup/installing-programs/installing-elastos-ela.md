# Installing Elastos ELA

Running the following command to install and configure Elastos ELA. ELA is the only program in the `mainchain` profile, and is also the first program installed by the `full` profile.

```bash
$ ~/node/node.sh ela init
```

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
```

A relatively strong password is required to generate the keystore file (nodepublickey wallet).

```
Please input a password (ENTER to use a random one)
? Password:
Generating random password...
Saving ela keystore password...
Checking ela keystore...
ADDRESS                            PUBLIC KEY
---------------------------------- ---------------------------------------------------------
EUX2Zz1r9bc6GtCHCD1qWfGEKzuY...... 03af7417cfef028a8138394c5fecb708b40b7dd512381a56a96......
---------------------------------- ---------------------------------------------------------
```

You must update the nodepublickey through the app, and complete the binding of the registered supernode to the server ELA node, in order to participate in the main network node consensus to gain rewards. After the node is synced, the `03...`/`02...` public key needed for Essentials is available from:

```bash
$ ~/node/node.sh ela status --verbose
```

```
INFO: ela config file: /home/ubuntu/node/ela/config.json
INFO: ela keystore file: /home/ubuntu/node/ela/keystore.dat
INFO: ela keystore password file: /home/ubuntu/.config/elastos/ela.txt
OK: ela initialized
```

The `init` command will try to find the server's public IP automatically, and record the result in ela config file. You can check it by running: 

```bash
$ cat ~/node/ela/config.json | jq .Configuration.DPoSConfiguration.IPAddress
```

The ELA main-chain RPC port (`20336`) is restricted by the config IP allow-list and is closed to the internet by the firewall. The peer-to-peer and DPoS ports (`20338`/`20339`) stay open. See [SECURITY.md](../../../../SECURITY.md) for the full port table.


