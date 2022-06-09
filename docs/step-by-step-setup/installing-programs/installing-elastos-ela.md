# Installing Elastos ELA

Running the following command to install and configure Elastos ELA.

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

A relatively strong password is required to generate the keystore file (the wallet).

```bash
Please input a password (ENTER to use a random one)
? Password:
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
