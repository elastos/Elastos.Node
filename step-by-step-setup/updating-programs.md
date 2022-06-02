# Updating Programs

### Upgrading a single program

We can **upgrade a single program** (chain). For example, to upgrade Elastos ELA, please run the following command.

```bash
$ ~/node/node.sh ela upgrade
```

Step 1: The script will contact the [download server](https://download.elastos.io/elastos-ela/) to find the **latest version**.

```bash
Finding the latest ela release...
INFO: Latest version: v0.8.3
```

Step 2: If you wish to continue, please answer the case-sensitive **Yes**. Any other answers will cancel the operation.

```bash
Proceed upgrade (No/Yes)? Yes
Downloading https://download.elastos.io/elastos-ela/elastos-ela-v0.8.3/elastos-ela-v0.8.3-linux-x86_64.tgz...
###################################################################### 100.0%
Extracting elastos-ela-v0.8.3-linux-x86_64.tgz...
```

Step 3: The script will **stop a running program** automatically.

```bash
Stopping ela...
...
ela         v0.8.3          Stopped
```

Step 4: And replace the files with the updated versions.

```bash
'/home/ubuntu/node/.node-upload/ela/ela' -> '/home/ubuntu/node/ela/ela'
'/home/ubuntu/node/.node-upload/ela/ela-cli' -> '/home/ubuntu/node/ela/ela-cli'
```

Step 5: If the script has stopped the program before the file replacement, it will **restart the program** automatically.

```bash
ela         v0.8.3          Running
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

Please check the **version** to make sure of a successful program upgrade.
