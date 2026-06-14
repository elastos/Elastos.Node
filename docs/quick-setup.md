# Quick Setup

### 1. Install the script

The fastest path runs the installer. It downloads `node.sh`, verifies the published checksum, and on a host that already runs a node migrates it onto Elastos Node for Ubuntu (restarting nothing):

```bash
$ curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
```

On a fresh host this installs `node.sh` and prints the next steps. Install the dependencies, then `node.sh setup` initializes the chains; open the peer/consensus ports separately with `node.sh firewall`, which detects your SSH port and asks before enabling:

```bash
$ sudo apt-get install -y jq lsof apache2-utils curl openssl
$ ~/node/node.sh setup
$ ~/node/node.sh firewall
```

To place the script by hand instead, download it and make it executable:

```bash
$ mkdir ~/node
$ cd ~/node
$ curl -O https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh
$ chmod a+x node.sh
```

### 2. Initialize programs

If you ran `setup`, the chains are already initialized and you can skip to step 3. To initialize on their own, the **init** command does the following automatically:

1. Downloads and extracts the prebuilt package
2. Prompts for the initial parameters (user name, crypto addresses, and wallet passwords)
3. Writes the required config files

```bash
$ ~/node/node.sh init
```

### 3. Start programs

The **start** command starts every chain in the active profile in the background.

```bash
$ ~/node/node.sh start
```

The **status** command shows the labeled status block for each program. Watch the **Height** to make sure the chains are **synchronized**.

```bash
$ ~/node/node.sh status
```

For a one-row-per-chain glance at the whole fleet (state, height, peers, sync), use **summary**:

```bash
$ ~/node/node.sh summary
```

Once the chains are synced, close public access to the RPC, oracle, and arbiter ports with **harden**. The RPC endpoints already bind to `127.0.0.1`; this command closes the firewall ports and reports any chain that still needs a restart:

```bash
$ ~/node/node.sh harden
```

Now the initial **setup is complete**.

Please refer to [the longer edition](archives/step-by-step-setup.md) for a more detailed setup and usage. For the security defaults and the port table, see [SECURITY.md](../SECURITY.md).

What's next:

* [See the status](archives/step-by-step-setup/program-version-and-status.md)
* [Use the client to connect](besides-setup/running-the-client.md)

For any issues, please get in touch with the blockchain Dev team via [Elastos Discord](https://discord.com/invite/Rcnz2pQkZS).
