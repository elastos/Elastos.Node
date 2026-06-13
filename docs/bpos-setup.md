# BPoS Setup

A new stake model to make consensus networks more decentralized as well as to improve the security and stability of the network, read more about [Elastos BPoS](https://www.cyberrepublic.org/suggestion/61b2d2c65e48d2007859c364).

## DPoS Supernode smooth transition to BPoS Supernode

Users who have already registered a DPoS super node register a BPoS super node through Essentials. The BPoS super node can share the nodepublickey of the DPoS 1.0 super node, and DPoS 1.0 node users do not need to change server configuration. The ELA mainnet node turns on BPoS consensus, then the BPoS super node participates in consensus and gets the reward.

## First BPoS Supernode setup

After registering the BPoS node with Essentials, complete the BPoS node build with the following steps. A BPoS node only requires the ELA main chain, so it runs the `mainchain` profile (a Council node, which also runs the side chains and arbiter, uses the `full` profile instead).

### Preparation

1. BPoS Supernode Ops please read [security](../SECURITY.md)
2. BPoS Supernode Ops please configure your server according to the server [requirements](overview/requirements.md)

### ELA node setup

1. Install `node.sh` with the one-liner. On a fresh host follow it with `node.sh setup` (dependencies, swap, firewall, autostart, then init):

   ```bash
   $ curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
   ```

2. Select the `mainchain` profile so only the ELA node is installed and managed:

   ```bash
   $ ~/node/node.sh profile set mainchain
   ```

3. Initialize and start the node, then bind the nodepublickey using Essentials:

   ```bash
   $ ~/node/node.sh init
   $ ~/node/node.sh start
   ```

4. Check the status of the node. The **status** command shows the program is **Running**. Watch the **Height** to make sure the chain is **synchronized**.

   ```bash
   $ ~/node/node.sh status
   ```

   For a one-row glance, use `~/node/node.sh summary`. To read the node's public key for Essentials once synced, run `~/node/node.sh ela status --verbose`.

### Governance commands

Registration is normally done through Essentials, but `node.sh` exposes the on-chain governance actions directly. They run only after ELA is fully synced. Commands may be written in snake_case or kebab-case (`register_bpos` or `register-bpos`).

```bash
$ ~/node/node.sh ela register_bpos NAME URL BLOCKS [REGION]
$ ~/node/node.sh ela activate_bpos
$ ~/node/node.sh ela vote_bpos PUB_KEY AMOUNT BLOCKS
$ ~/node/node.sh ela stake_bpos AMOUNT
$ ~/node/node.sh ela claim_bpos AMOUNT [ELA_ADDRESS]
$ ~/node/node.sh ela unstake_bpos AMOUNT [ELA_ADDRESS]
$ ~/node/node.sh ela unregister_bpos
```

### Node upgrade tools

* Keep the script current with `~/node/node.sh update_script` (checksum-verified; `script_update` also works). Update the chain binaries with `~/node/node.sh update`.
* Use this tool [Elastos.ELA.MiscTools](https://github.com/elastos/Elastos.ELA.MiscTools) to quickly complete node upgrades

### FAQ

* Node [faq](appendix/faq.md)
* To find out more [Info](../SUMMARY.md)
* You can also consult [Gelaxy Team](https://discord.gg/UAyyVt3Fch)
