# Elastos Node for Ubuntu

Elastos Node for Ubuntu is the node management tool for running Elastos nodes on Ubuntu. It manages the Elastos main chain (ELA), the EVM side chains (ESC, EID, PG), their cross-chain oracles, and the arbiter through a single `node.sh` script.

It focuses on two areas:

- **Security defaults.** JSON-RPC and WebSocket endpoints bind to `127.0.0.1`, no signing account is unlocked at startup, the exposed RPC API surface is reduced, and self-update verifies a published SHA-256 checksum. See [SECURITY.md](SECURITY.md).
- **Deployment profiles.** A node can run the main chain only, or the full cross-chain stack. See [Deployment profiles](#deployment-profiles).

All commands from the original Elastos.Node runner continue to work unchanged. It uses the same directory layout, binaries, keystore files, and log scheme as the previous runner, so it functions as a drop-in replacement on an existing installation. A full feature comparison is available in [docs/COMPARISON.md](docs/COMPARISON.md).

## Supported components

| Component | Description |
|---|---|
| `ela` | Elastos main chain (BPoS consensus, CR Council governance) |
| `esc` | Elastos Smart Chain (EVM side chain) |
| `eid` | Elastos Identity Chain (EVM side chain) |
| `pg` | PGA chain (EVM side chain) |
| `esc-oracle`, `eid-oracle`, `pg-oracle` | Cross-chain oracle services |
| `arbiter` | Cross-chain arbiter |

The decommissioned ECO and PGP side chains are excluded from all profiles and are not started by this script. A leftover ECO installation from the original Elastos.Node runner can be stopped and removed with `node.sh eco purge`; the command detects whether ECO is present and does nothing on nodes without it.

## Requirements

- Ubuntu (tested on 22.04 and 24.04)
- `curl`, `jq`, and the packages installed automatically by `setup`
- Open inbound peer-to-peer and consensus ports (handled by `setup` or the `firewall` command; see [SECURITY.md](SECURITY.md) for the port table)

## Installation

Place the script by hand:

```bash
mkdir ~/node && cd ~/node
curl -O https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh
chmod a+x node.sh
```

Then continue with [Quick start](#quick-start) below (`./node.sh setup`). On a host that already runs a node, move it onto Elastos Node for Ubuntu instead — this preserves keystores and chain data and restarts nothing:

```bash
./node.sh migrate
```

<details>
<summary>Or use the one-line installer (downloads + verifies the published checksum for you; runs <code>migrate</code> on an existing install)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
```

</details>

## Quick start

```bash
./node.sh setup      # dependencies + swap + firewall + autostart, then init
./node.sh start
./node.sh summary
```

`setup` prompts for the deployment profile (main chain only, or full stack) and uses `sudo` for system changes. It also installs a global `node.sh` wrapper in `/usr/local/bin`, so subsequent commands can be run from any directory.

To perform the steps individually instead:

```bash
./node.sh profile set mainchain   # or: full
./node.sh init                    # download binaries + create the keystore
./node.sh firewall                # open peer/consensus ports (RPC stays on loopback)
./node.sh start
```

Side chains that mine should be given a cold reward address. Without one they still start, but print a prominent red warning, because block rewards then credit the node's local hot account:

```bash
node.sh reward set 0xYOURCOLDADDRESS
```

## Deployment profiles

| Profile | Runs | Intended use |
|---|---|---|
| `mainchain` | `ela` | BPoS supernode, CR Council node, or a standalone ELA full node |
| `full` (default) | `ela`, `esc`, `eid`, `pg`, the three oracles, `arbiter` | Full cross-chain stack |

The profile is persisted to `~/.config/elastos/profile` and governs the bulk commands (`start`, `stop`, `status`, `update`, `summary`, `health`).

```bash
node.sh profile                    # show the active profile
node.sh profile set mainchain      # change it
node.sh --profile full status      # override for a single command
```

Individual chains can always be addressed directly, regardless of profile:

```bash
node.sh esc start
node.sh ela status
```

## Command reference

### Global commands

| Command | Description |
|---|---|
| `setup` | Prepare a fresh host: dependencies, 16 GB swap, firewall, autostart, then `init` |
| `init` | Download binaries and create the keystore |
| `start` / `up` | Start every chain in the active profile |
| `stop` / `down` | Stop every chain in the active profile |
| `restart` | Restart the profile's chains one at a time (excludes `ela` unless `--force` is given) |
| `status` | Per-chain labeled status block for the active profile |
| `summary` / `ps` | One row per chain: state, height, peers, sync (`--json` available) |
| `health` | One-line verdict per chain; exits non-zero if any chain is unhealthy |
| `logs [<chain>] [-f]` | Show the most recent log for a chain (`-f` to follow) |
| `update` | Update chain binaries |
| `update_script` | Update `node.sh` itself (checksum-verified) and re-close the firewall |
| `profile [set <p>]` | Show or set the deployment profile |
| `firewall` | Open the peer/consensus ports for the active profile |
| `harden` | Close public access to the RPC, oracle, and arbiter ports; report any chain that still needs a restart |
| `reward [set <0x..>]` | Show or set the cold mining reward address for all side chains |
| `migrate [--dry-run]` | Move an existing installation (the original Elastos.Node runner or an earlier version) onto Elastos Node for Ubuntu |
| `migrate --apply [--yes]` | Staged restart that applies the hardened RPC binding (side chains only) |
| `uninstall` | Stop all processes and remove the installation (keystore backed up first) |
| `version` / `-v` | Script and chain versions |
| `help` / `-h` | Full command reference |

### Per-chain commands

```
node.sh <chain> <command>
```

where `<chain>` is one of `ela`, `esc`, `esc-oracle`, `eid`, `eid-oracle`, `pg`, `pg-oracle`, `arbiter`.

| Command | Description |
|---|---|
| `start` / `up`, `stop` / `down`, `restart` | Process control |
| `status [--json]` | Labeled status block, or machine-readable with `--json` |
| `health` | Single-chain health check with exit code |
| `logs [-f]` | Most recent log file |
| `client` | Invoke the chain's CLI client |
| `jsonrpc` / `rpc` | Send a JSON-RPC request to the chain |
| `init`, `update`, `version` | Per-chain lifecycle |
| `compress_log`, `remove_log` | Log maintenance |
| `purge` (eco only) | Stop eco and eco-oracle and delete their data; keystore backed up first |

ELA additionally supports the governance commands from the original Elastos.Node runner: `register_bpos`, `activate_bpos`, `unregister_bpos`, `vote_bpos`, `stake_bpos`, `unstake_bpos`, `claim_bpos`, `register_crc`, `activate_crc`, `unregister_crc`, `send`, `transfer`. Commands may be written in kebab-case (`register-bpos`) or snake_case (`register_bpos`).

### Output control

| Flag / variable | Effect |
|---|---|
| `--json` | Machine-readable output for `summary` and `status` |
| `--no-color` or `NO_COLOR=1` | Disable ANSI color |
| `--profile <p>` | Override the active profile for one command |
| Non-TTY `status` | Falls back to the classic full dump so existing parsers keep working |

## Security model

Summary of the defaults; details and the full port table are in [SECURITY.md](SECURITY.md).

- RPC and WebSocket bind to `127.0.0.1`. The bind address can be changed deliberately via the `EVM_RPC_BIND` environment variable or `~/.config/elastos/evm_rpc_bind`; an invalid value falls back to `127.0.0.1`.
- Hardening applies in two layers. The host firewall is closed on the RPC ports automatically by `migrate`, `update_script`, and the `harden` command (this takes effect immediately and restarts nothing). The daemon bind to `127.0.0.1` and the removal of `--unlock`/`personal` take effect when a chain is next restarted. `harden` reports which running chains still need that restart.
- No `--unlock` and no `--allow-insecure-unlock`. Block production signs with the dedicated PBFT/ELA keystore, so sealing is unaffected.
- The `personal`, `admin`, `db`, and `miner` RPC namespaces are not exposed.
- A mining side chain without a cold reward address starts with a prominent red warning that block rewards credit the node's local hot account. Set a cold address with `reward set`.
- `update_script` verifies a published SHA-256 checksum and a syntax check before replacing the script.
- The ELA `sponsors` file required past block ~1,801,550 is downloaded automatically when missing.
- The main-chain status query that can panic a syncing daemon is gated behind a sync check and reports `N/A` until the node is synced.

For remote monitoring, use an SSH tunnel or VPN rather than exposing RPC ports.

## Migrating an existing node

The `migrate` command moves an installation running the original Elastos.Node `node.sh`, or an earlier version, onto the current version. It preserves the keystore, chain data, and configuration, writes a rollback snapshot, and never restarts or deletes anything by itself.

```bash
node.sh migrate --dry-run    # preview, changes nothing
node.sh migrate              # write the profile + rollback snapshot
node.sh migrate --apply      # staged side-chain restarts to apply the hardened binding
```

`migrate --apply` restarts only stale side chains, one at a time, verifying each returns on `127.0.0.1` before continuing. The ELA main chain is never restarted, so a council producer keeps signing throughout. The full procedure, including verification and rollback, is documented in [docs/MIGRATION.md](docs/MIGRATION.md).

## Updating

Once a node is on Elastos Node for Ubuntu, a single command keeps the script current:

```bash
node.sh update_script
```

It downloads `node.sh` from this repository, verifies it against the published `node.sh.sha256`, runs a syntax check, and only then replaces the installed script. To update the chain binaries instead:

```bash
node.sh update
```

Chain binaries are updated from the official Elastos distribution servers.

## File locations

| Path | Purpose |
|---|---|
| `~/node/` | Installation root (one subdirectory per chain) |
| `~/node/<chain>/` | Binary, configuration, and data for a chain |
| `~/node/<chain>/logs/` | Rotated log files |
| `~/.config/elastos/` | Keystore passwords, profile, node configuration |
| `~/.config/elastos/profile` | Active deployment profile |
| `/usr/local/bin/node.sh` | Global wrapper installed by `setup` |

## Versioning

Releases are tagged `vMAJOR.MINOR.PATCH` and documented in [CHANGELOG.md](CHANGELOG.md). The running version is shown by `node.sh version`.

## License

This project builds on the [Elastos.Node](https://github.com/elastos/Elastos.Node) project and follows its licensing. See the Elastos.Node repository for the license terms.

## Acknowledgements

Elastos Node for Ubuntu builds on the [`elastos/Elastos.Node`](https://github.com/elastos/Elastos.Node) tooling created by the Elastos contributors. It adds the security hardening, deployment profiles, migration tooling, and operator interface documented above.
