---
description: WIP...
---

# Elastos Node Components

Elastos blockchain consists of the following components.

programs (blockchain daemons/services and related programs).

This document may describe these components as chains, daemons, services, or programs because they are all required for the Elastos blockchain.

Although not all users need to host all of them. Some users may need to setup at least one of them.

Check their respective project pages for more information.

| Chain / Program   | Description                                                                | Repository                                                                                                           |
| ----------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| ELA               | Main chain service (BPoS consensus, CR Council governance)                | [https://github.com/elastos/Elastos.ELA](https://github.com/elastos/Elastos.ELA)                                     |
| ESC               | Elastos Smart Chain service (EVM side chain)                              | [https://github.com/elastos/Elastos.ELA.SideChain.ESC](https://github.com/elastos/Elastos.ELA.SideChain.ESC)         |
| ESC-Oracle        | Cross-chain oracle relaying deposits and withdrawals between ELA and ESC  | [https://github.com/elastos/Elastos.ELA.SideChain.ESC](https://github.com/elastos/Elastos.ELA.SideChain.ESC)         |
| EID               | Elastos Identity Chain service (EVM side chain)                           | [https://github.com/elastos/Elastos.ELA.SideChain.EID](https://github.com/elastos/Elastos.ELA.SideChain.EID)         |
| EID-Oracle        | Cross-chain oracle relaying deposits and withdrawals between ELA and EID  | [https://github.com/elastos/Elastos.ELA.SideChain.EID](https://github.com/elastos/Elastos.ELA.SideChain.EID)         |
| PG                | PGA chain service (EVM side chain)                                        | [https://github.com/elastos/Elastos.ELA.SideChain.ESC](https://github.com/elastos/Elastos.ELA.SideChain.ESC)         |
| PG-Oracle         | Cross-chain oracle relaying deposits and withdrawals between ELA and PG   | [https://github.com/elastos/Elastos.ELA.SideChain.ESC](https://github.com/elastos/Elastos.ELA.SideChain.ESC)         |
| Arbiter           | Cross-chain arbiter coordinating transfers across the main and side chains | [https://github.com/elastos/Elastos.ELA.Arbiter](https://github.com/elastos/Elastos.ELA.Arbiter)                     |

The decommissioned ECO and PGP side chains are not supported and are not started by node.sh. A leftover ECO installation can be stopped and removed with `node.sh eco purge`.
