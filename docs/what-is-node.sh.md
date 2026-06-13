# node.sh

**node.sh** is a wrapper script to help you manage your Elastos nodes relatively easily. This documentation covers Elastos Node for Ubuntu ([`elastos/Elastos.Node`](https://github.com/elastos/Elastos.Node)), a v1.1 of the runner that binds RPC to loopback, unlocks no account at startup, and verifies a checksum on self-update. See [SECURITY.md](../SECURITY.md) for the full security model.

To setup, manage or operate an Elastos node, you may have to do the following deployment works:

* Installation
* Starting
* Stopping
* Updating
* Tracking versions
* Monitoring
* Uninstallation

It seems easy and straightforward, but actually a little complicated and error-prone. Especially considering Elastos blockchain has multiple components and modes.

We wish to share a basic and effective way to manage a node. It is for entry-level to mid-level users, especially if you have not prepared or brewed a similar solution.

node.sh integrates some frequently-used operations and provides a command-line interface in an all-in-one, intuitive, and consistent way.

The fastest way to install it on a fresh host is the one-liner, which also migrates an existing node onto Elastos Node for Ubuntu without touching keystores or chain data:

```bash
curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
```

Then run `node.sh setup` for a turnkey host preparation (dependencies, swap, firewall, autostart, then init).

node.sh supports:

* **Operating System**: Ubuntu Linux x86\_64 18.04 or higher
* **Elastos Network**: MainNet and TestNet
* [**Chains**](overview/programs-supported-by-node.sh.md): Elastos main chain, the EVM side chains (ESC, EID, PG), their cross-chain oracles, and the arbiter
* **Deployment profiles**: `mainchain` (main chain only) or `full` (the full cross-chain stack)
