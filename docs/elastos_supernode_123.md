# Elastos Supernode: Setup 1-2-3

### 1. Download the automatic script

The following shell command will **download** the current version of the **script** and make it **executable**.

```bash
$ mkdir ~/node
$ cd ~/node
$ curl -O https://raw.githubusercontent.com/elastos/Elastos.ELA.Supernode/master/build/skeleton/node.sh
$ chmod a+x node.sh
```

### 2. Initialize programs

The **init** command will do the following jobs automatically:

- downloads and extract the prebuilt package
- prompts the user to enter the initial parameters (which include a user name, crypto addresses, and wallet passwords)
- writes the config files required

```bash
$ ~/node/node.sh init
```

### 3. Start programs

The **start** command will start all the programs (chains) in the background.

```bash
$ ~/node/node.sh start
```

The **status** command will show all programs (chains) are **Running**. Watch the **Height** to make sure the chains are **synchronized**.

```bash
$ ~/node/node.sh status
```

Now the initial **setup complete**.

For a more detailed setup and usage, please refer to [Elastos Supernode Guide](./elastos_supernode_usage.md). 

Any issues, please contact the blockchain Dev team.

