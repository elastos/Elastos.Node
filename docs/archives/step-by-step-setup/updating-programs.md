# Updating Programs

This page covers updating the chain **binaries**. To update the `node.sh` script itself, see [Updating node.sh](updating-node.sh.md).

### Updating a single program

You can **update a single program** (chain). For example, to update Elastos ELA, run the following command.

```bash
$ ~/node/node.sh ela update
```

Step 1: The script contacts the [download server](https://download.elastos.io/elastos-ela/) to find the **latest version**.

```bash
Finding the latest ela release...
INFO: Latest version: v0.9.5
```

Step 2: To continue, answer the case-sensitive **Yes**. Any other answer cancels the operation.

```bash
Proceed update (No/Yes)? Yes
Downloading https://download.elastos.io/elastos-ela/elastos-ela-v0.9.5/elastos-ela-v0.9.5-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-ela-v0.9.5-linux-x86_64.tgz...
```

Step 3: The script **stops a running program** automatically.

```bash
Stopping ela...
...
ela         v0.9.5          Stopped
```

Step 4: It replaces the files with the updated versions.

```bash
'/home/ubuntu/node/.node-upload/ela/ela' -> '/home/ubuntu/node/ela/ela'
'/home/ubuntu/node/.node-upload/ela/ela-cli' -> '/home/ubuntu/node/ela/ela-cli'
```

Step 5: If the script stopped the program before the file replacement, it **restarts the program** automatically.

```bash
ela         v0.9.5          Running
Disk:       61M
PID:        120480
RAM:        710168K
Uptime:     00:01
#Files:     41
TCP Ports:  IPv4_*:20338 IPv6_*:20338 IPv4_*:20339 IPv6_*:20339 IPv4_*:20336 
#TCP:       14
#Peers:     3
Height:     18313
```

Check the **version** to confirm a successful program update.

```bash
$ ~/node/node.sh version
```

### Updating all programs

Running **update** without a chain name updates every chain binary in the active profile.

```bash
$ ~/node/node.sh update
[ ... many messages follow ... ]
```

Chain binaries are downloaded from the official Elastos distribution servers. The chains updated depend on the active profile; see [Deployment profiles](../../../README.md#deployment-profiles).
