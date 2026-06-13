# Installing node.sh

## One-line install (recommended)

One command installs the script. On a host that already runs a node, it also migrates that node onto Elastos Node for Ubuntu. It verifies the published SHA-256 checksum and never touches keystores or chain data:

```bash
$ curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
```

- On a **fresh host** it installs `node.sh` into `~/node` and points you to `node.sh setup`.
- On an **existing node** (the original Elastos.Node runner or an earlier version) it backs up the old `node.sh`, swaps in Elastos Node for Ubuntu, and runs `migrate`, which restarts nothing.

To review the installer before running it, download it first:

```bash
$ curl -fsSL -o install.sh https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh
$ less install.sh && bash install.sh
```

After installing on a fresh host, run the turnkey setup, which installs dependencies, adds swap, configures the firewall, enables autostart, and initializes the node:

```bash
$ node.sh setup
```

See [Running node.sh](running-node.sh.md) for what `setup` does and the manual alternative.

## Manual install (alternative)

To place the script by hand, create a folder in your `$HOME` to hold the executable, config, and data files:

```bash
$ mkdir ~/node
$ cd ~/node
```

Download the current version of the script and make it executable:

```bash
$ curl -fsSLO https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh
$ chmod a+x node.sh
```

Once installed, keep the script current with the checksum-verified self-update:

```bash
$ node.sh update_script
```
