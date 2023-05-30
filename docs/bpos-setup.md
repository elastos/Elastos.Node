# BPoS Setup

A new stake model to make consensus networks more decentralized as well as to improve the security and stability of the network, read more about [Elastos BPoS](https://www.cyberrepublic.org/suggestion/61b2d2c65e48d2007859c364).

## DPoS Supernode smooth transition to BPoS Supernode

Users who have already registered DPoS super node register BPoS super node through Essentials, BPoS super node can share the nodepublickey of DPoS1.0 super node, and DPoS1.0 node users do not need to change server configuration, ELA mainnet node turns on BPoS consensus, then BPoS super node participates in the consensus block and gets the reward.

## First BPoS Supernode setup

After registering the BPoS node with Essentials, complete the BPoS node build with the following steps BPoS nodes only require ELA nodes to be installed.

### Preparation

1. BPoS Supernode Ops please read [security](archives/security.md)
2. BPoS Supernode Ops please configure your server according to the server [requirements](overview/requirements.md)

### ELA node setup

1. A tool to quickly deploy nodes [node.sh](step-by-step-setup/installing-node.sh.md)
2. The [ela](step-by-step-setup/installing-programs/installing-elastos-ela.md) node is deployed and the nodepublickey is bound using Essentials
3. [Start ela](step-by-step-setup/starting-programs.md) node to synchronize block data on the main network
4. Check the status of a node. The **status** command will show all programs (chains) are **Running**. Watch the **Height** to make sure the chains are **synchronized**.

```bash
$ ~/node/node.sh status
```

### Node upgrade tools

* Use this tool [Elastos.ELA.MiscTools](https://github.com/elastos/Elastos.ELA.MiscTools) to quickly complete node upgrades

### FAQ

* Node [faq](appendix/faq.md)
* To find out more [Info](../SUMMARY.md)
* You can also consult [Gelaxy Team](https://discord.gg/UAyyVt3Fch)
