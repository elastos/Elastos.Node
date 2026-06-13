# CRC Supernode Setup

The Cyber Republic Consensus is the third Elastos consensus mechanism after PoW and BPoS. The purpose of CRC is to
provide a consensus-based community governance mechanism that will drive Elastos' technological and ecosystem
development, dispute resolution, and management of community assets, and establish incentives to foster community
participation in the governance of and contribution to the Elastos community.

## First CRC Supernode setup

After registering the CRC node with Essentials, complete the CRC node build with the following steps. A Council node runs the `full` profile, which manages the ELA main chain together with the EVM side chains (ESC, EID, PG), their oracles, and the arbiter.

### Preparation

1. CRC Supernode Ops please read [security](../SECURITY.md)
2. CRC Supernode Ops please configure your server according to the server [requirements](overview/requirements.md)

### ELA node setup

1. Install `node.sh` with the one-liner, then run `node.sh setup` on a fresh host (dependencies, swap, firewall, autostart, then init):

   ```bash
   $ curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
   $ ~/node/node.sh setup
   ```

   When `setup` prompts for the profile, choose the full stack. To set it explicitly:

   ```bash
   $ ~/node/node.sh profile set full
   ```

   This installs all programs in one pass: ELA, ESC, EID, PG, the ESC/EID/PG oracles, and the arbiter. View more sample [programs](archives/step-by-step-setup/installing-programs).

2. Start the node and bind the nodepublickey using Essentials:

   ```bash
   $ ~/node/node.sh start
   ```

3. Check the fleet. The **status** command shows the labeled block for each program; **summary** gives one row per chain (state, height, peers, sync):

   ```bash
   $ ~/node/node.sh status
   $ ~/node/node.sh summary
   ```

   Once the chains are synced, close public access to the RPC, oracle, and arbiter ports with `~/node/node.sh harden`. The side-chain RPC endpoints bind to `127.0.0.1`; see [SECURITY.md](../SECURITY.md) for the port table.

### Governance commands

Registration is normally done through Essentials, but `node.sh` exposes the CRC governance actions directly. They run only after ELA is fully synced. Commands may be written in snake_case or kebab-case (`register_crc` or `register-crc`).

```bash
$ ~/node/node.sh ela register_crc NAME URL [REGION]
$ ~/node/node.sh ela activate_crc
$ ~/node/node.sh ela unregister_crc
```

### Node upgrade tools

* Keep the script current with `~/node/node.sh update_script` (checksum-verified; `script_update` also works). Update the chain binaries with `~/node/node.sh update`.
* Use this tool [Elastos.ELA.MiscTools](https://github.com/elastos/Elastos.ELA.MiscTools) to quickly complete node
  upgrades

### FAQ

* Node [faq](appendix/faq.md)
* To find out more [Info](../SUMMARY.md)
* You can also consult [Gelaxy Team](https://discord.gg/UAyyVt3Fch)
