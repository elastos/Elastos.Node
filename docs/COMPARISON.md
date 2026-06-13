# What changed in this version

This document compares Elastos Node for Ubuntu with the original [`elastos/Elastos.Node`](https://github.com/elastos/Elastos.Node) `node.sh`. All observations were verified against the original script in the `build/skeleton` directory of that repository.

## Summary

Elastos Node for Ubuntu keeps the original data layout, binaries, daemons, and commands, and changes the security defaults, status accuracy, and operator interface. The original script is approximately 5,700 lines; this version is approximately 6,700 lines.

## Security

| Area | Earlier Elastos.Node runner | Elastos Node for Ubuntu |
|---|---|---|
| EVM RPC binding | `--rpcaddr '0.0.0.0'` on every EVM chain; JSON-RPC reachable from the network | `127.0.0.1`, with a validated, explicit override (`EVM_RPC_BIND`) |
| EVM WebSocket | `--wsaddr '0.0.0.0' --wsorigins '*'`, no `--wsapi` restriction | Same loopback bind as RPC |
| Account unlock | `--unlock <account> --allow-insecure-unlock` on every mining chain; combined with the public RPC bind, this permits unauthenticated `eth_sendTransaction` from the network | Removed. Block sealing is unaffected; consensus signs with the PBFT/ELA keystore |
| RPC API surface | Mining: `db,eth,net,pbft,personal,txpool,web3` (EID also `miner`); follower: `admin,eth,net,txpool,web3` | Mining: `eth,net,web3,txpool,pbft`; follower: `eth,net,web3,txpool` |
| Mining rewards | Default to the node's local account unless a reward address file is created manually; no warning | Same default, but every start of a mining chain without a cold reward address prints a prominent red warning; `reward set` configures all side chains at once |
| Script self-update | Downloads the original Elastos.Node master branch with no checksum and no syntax check | Downloads this repository, verifies the published SHA-256 checksum, and runs `bash -n` before installing |
| Firewall | Not managed by the script | `firewall` opens only the peer and consensus ports; `harden` closes the RPC, oracle, and arbiter RPC ports, and is run automatically by `migrate` and `update_script` |
| Hardening on update | No mechanism | `migrate` and `update_script` close the public RPC/oracle/arbiter ports automatically; `harden` reports which chains still need a restart to rebind |

## Reliability and status accuracy

| Area | Earlier Elastos.Node runner | Elastos Node for Ubuntu |
|---|---|---|
| `status` on a syncing main chain | Calls `dposv2rewardinfo` unconditionally; this RPC can panic the ELA daemon during synchronization | Gated behind a sync check; reports `N/A` until the node is synced |
| ELA `sponsors` file | Not handled; a fresh or restored main chain stalls at approximately block 1,801,550 | Downloaded automatically at start when missing (mainnet) |
| RPC failures in status | `jq` failures can print the literal string `null`; hex values parsed with arithmetic expansion can be misread | Unreachable RPC values are shown as `N/A`; hex values use a dedicated converter; a genuine `0` is still shown as `0` |
| Start verification | Fixed `sleep` followed by a status print; a daemon that exits on launch is not reported | Post-start verification for every chain and oracle, with the last log lines on failure |
| Sync state | Height shown without a reference point | `summary` and `health` derive synced, syncing, and stalled states per chain |
| Exit codes | Commands generally exit 0 regardless of outcome | `health`, `start`, and `restart` exit non-zero on failure; unknown commands exit non-zero |
| Error messages | Single-line error without guidance | Errors state what happened and the next action; misspelled commands receive suggestions |

## Operator interface

| Area | Earlier Elastos.Node runner | Elastos Node for Ubuntu |
|---|---|---|
| Installation | Manual steps from the documentation: dependencies, swap, firewall, cron, then per-chain `init` | `setup`: one command for dependencies, swap, firewall, autostart, and `init` |
| Deployment shape | Full stack only | `mainchain` and `full` profiles; `--profile` override per command |
| Command style | `./node.sh <chain> <command>` | Unchanged, plus `up`, `down`, `restart`, `ps`, `logs [-f]`, `version`, `rpc`, and a global `node.sh` wrapper |
| Fleet overview | Per-chain status blocks only | `summary` (one row per chain) and `health` (verdict with exit code) |
| Machine output | None | `--json` on `summary` and `status`; `--no-color` and `NO_COLOR` support |
| Log access | Locate the rotated log file manually | `logs [<chain>] [-f]` selects the most recent log |
| ECO / PGP chains | ECO listed and started despite decommission | Excluded from profiles and dispatch |
| Help | Generated list of chain names only | Grouped reference covering every command; per-chain help |

## Migration and operations

These commands have no equivalent in the original Elastos.Node runner:

- `migrate [--dry-run]` detects an installation from the original Elastos.Node runner or an earlier version, preserves the keystore, chain data, and configuration, writes rollback snapshots, and never restarts or deletes anything.
- `migrate --apply` applies the hardened RPC binding by restarting stale side chains one at a time, verifying each returns on `127.0.0.1`. The ELA main chain is never restarted.
- `uninstall` stops all processes, backs up the keystore, and removes the installation after typed confirmation.
- `eco purge` stops the decommissioned ECO chain and its oracle and deletes their data, with a keystore backup first. It acts only on nodes where ECO is actually present; `migrate` reports such nodes.

## Unchanged by design

The following are identical to the original Elastos.Node runner, which is what makes Elastos Node for Ubuntu a drop-in replacement on an existing node:

- Directory layout (`~/node/<chain>/`), binary sources, and download URLs
- Keystore and password file locations and formats
- Log rotation scheme (`rotatelogs`) and the log compression cron
- All legacy commands, including the BPoS and CRC governance commands
- Chain data formats; no resync is required when switching
