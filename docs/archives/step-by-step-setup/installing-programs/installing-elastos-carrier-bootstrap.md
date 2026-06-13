# Installing Elastos Carrier Bootstrap

The Carrier bootstrap node is not managed by this runner. `node.sh` covers the Elastos main chain (`ela`), the EVM side chains (`esc`, `eid`, `pg`), their cross-chain oracles, and the `arbiter`. There is no `carrier` chain in `node.sh`, and it is not part of either deployment profile, so `node.sh carrier init` is not a valid command.

To run a Carrier bootstrap node, use the Carrier project directly:

- Carrier project: [https://github.com/elastos/Elastos.NET.Carrier.Bootstrap](https://github.com/elastos/Elastos.NET.Carrier.Bootstrap)
- Binary releases: [https://download.elastos.io/elastos-carrier](https://download.elastos.io/elastos-carrier)

For the programs this runner does install, see the per-program pages for `ela`, `esc`, `esc-oracle`, `eid`, `eid-oracle`, `pg`, `pg-oracle`, and `arbiter`.
