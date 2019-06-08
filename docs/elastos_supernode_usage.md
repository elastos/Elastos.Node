# Elastos Supernode Usage


## 1. Installation

### 1.1. Download tarball

Download the nodes.tar.gz to the folder where you prepare to run supernode.

```bash
$ wget node.tar.gz
```

### 1.2. Verify checksum

```bash
$ wget node.tar.gz.digest
$ shasum -c node.tar.gz.digest
```

### 1.3. Verify PGP signature

```bash
$ wget node.tar.gz.asc
$ pgp -v node.tar.gz.asc
```

### 1.4. Unpack tarball

```bash
$ tar xf elastos-supernode-*.tgz
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

### 1.5. Verify the contents

```bash
$ cd ~/node
$ shasum -a 256 SHA256SUM
$ find node
```

## 2. Running

`~/node/node.sh` is the main script for maintaining nodes. You can use this script to complete node initialization, startup, shutdown, and so on.

### 2.1. Configure

```bash
$ ~/node/node.sh init
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

### 2.2. Start

```bash
$ ~/node/node.sh start
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

### 2.3. Stop

Stop ela, did, token and carrier nodes.

```bash
$ ~/node/node.sh stop
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

### 2.4. Status

Check node status

```bash
$ ~/node/node.sh status
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

## 3. Maintanence

### 3.1. Monitoring

TODO

### 3.2. Upgrading

TODO

### 3.3. Diagnostic

TODO

