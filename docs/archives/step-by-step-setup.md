# Step-by-Step Setup

This is a walkthrough for installing and running `node.sh`, the security-hardened Elastos node runner.

It manages the Elastos main chain (ELA), the EVM side chains (ESC, EID, PG), their cross-chain oracles, and the arbiter through a single script.

The fastest path is the one-line installer followed by `node.sh setup`, which prepares a fresh host and initializes the node. The pages that follow cover that flow and the manual alternative:

1. [Checking Environments](step-by-step-setup/checking-environments.md)
2. [Installing node.sh](step-by-step-setup/installing-node.sh.md)
3. [Running node.sh](step-by-step-setup/running-node.sh.md)

For the security defaults and the port table, see [SECURITY.md](../../SECURITY.md). To move an existing upstream node onto this runner, see the [migration guide](../MIGRATION.md).
