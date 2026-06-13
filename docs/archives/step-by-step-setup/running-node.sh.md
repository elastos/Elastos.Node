# Running node.sh

## Selecting the network

When running `node.sh` for the first time, it asks you to select a network.

```bash
$ ~/node/node.sh
```

Both MainNet and TestNet are supported. Press Enter to accept the default MainNet, or enter `2` and press Enter for TestNet.

```bash
Please select the network:

  1. MainNet
  2. TestNet

? Your option: [1] ENTER
INFO: config file: $HOME/.config/elastos/node.json
```

The script then continues with whatever command you ran, so you no longer need to run it twice.

## Turnkey setup

On a fresh host, `setup` does the whole preparation in one step: it installs dependencies, adds 16 GB of swap, configures the firewall, enables autostart on reboot, installs a global `node.sh` wrapper in `/usr/local/bin`, and initializes the chains. It uses `sudo` for the system changes.

```bash
$ node.sh setup
$ node.sh start
$ node.sh summary
```

`setup` first asks which deployment profile to run:

```bash
What will this node run?
  [1] Main chain only        (ELA)
  [2] Full stack             (ELA + side chains + oracles + arbiter)
```

To run the equivalent steps individually instead:

```bash
$ node.sh profile set mainchain   # or: full
$ node.sh init                    # download binaries + create the keystore
$ node.sh firewall                # open peer/consensus ports (RPC stays on 127.0.0.1)
$ node.sh start
```

## Command reference

Run `node.sh` with no arguments, or `node.sh help`, to print the command list:

```bash
$ node.sh help
```

{% code fullWidth="false" %}
```bash
Elastos Node for Ubuntu v1.1.0

Usage:  node.sh <command> [options]
        node.sh <chain> <command> [options]

DAILY
  start | stop       start / stop every chain in the profile
  summary            one row per chain: state, height, peers (add --json)
  status             full status for the profile (--verbose for everything)
  logs [chain] [-f]  tail a chain's log
  health             exit-code health check (0 = all healthy; cron-friendly)

SETUP
  setup              prepare a fresh box + initialize (deps, swap, firewall, autostart)
  init               download binaries + create the keystore
  profile [set P]    choose what this node runs (mainchain | full)
  firewall           open peer/consensus ports (RPC stays on 127.0.0.1)
  harden             close public RPC ports + report any restart needed
  reward [set 0x..]  cold miner reward address for the side chains

MANAGE
  restart            restart the profile's chains, one at a time (ela needs --force)
  update             update the chain binaries
  migrate            move an existing install onto this tool (--dry-run | --apply)
  uninstall          stop + remove the install (keystore backed up)
  version | -v       tool + chain versions

PER-CHAIN    node.sh <chain> <command>
  start stop restart status [--json] health logs [-f] client rpc init update version
  run 'node.sh <chain>' for that chain's full list (ela: governance; eco: purge)

CHAINS       ela esc esc-oracle eid eid-oracle pg pg-oracle arbiter
ALIASES      up=start   down=stop   ps=summary   rpc=jsonrpc   (kebab-case accepted)
MAINTAIN     set_cron   update_script   set_path
FLAGS        --profile <mainchain|full>   --no-color
```
{% endcode %}

The first argument is either a global command or a chain name. When it is a chain name, the second argument is the action for that chain. `N/A` means a chain is not installed.

### Deployment profiles

A node runs either the main chain only or the full cross-chain stack. The profile is persisted to `~/.config/elastos/profile` and governs the bulk commands (`start`, `stop`, `status`, `summary`, `health`, `update`).

```bash
$ node.sh profile                 # show the active profile
$ node.sh profile set mainchain   # ELA main chain only
$ node.sh profile set full        # ELA + side chains (esc, eid, pg) + oracles + arbiter
$ node.sh --profile full status   # override for a single command
```

| Profile | Runs |
|---|---|
| `mainchain` | `ela` |
| `full` (default) | `ela`, `esc`, `eid`, `pg`, the three oracles, `arbiter` |

The decommissioned ECO and PGP side chains are not part of any profile. A leftover ECO install can be removed with `node.sh eco purge`.

### Per-chain commands

```bash
$ node.sh <chain> <command>
```

where `<chain>` is one of `ela`, `esc`, `esc-oracle`, `eid`, `eid-oracle`, `pg`, `pg-oracle`, `arbiter`. Run `node.sh <chain>` with no command to see that chain's list.

| Command | Description |
|---|---|
| `start` / `up`, `stop` / `down`, `restart` | Process control |
| `status [--json]` | Labeled status block, or machine-readable with `--json` |
| `health` | Single-chain health check with an exit code |
| `logs [-f]` | Most recent log file (`-f` to follow) |
| `client` | Run the chain's CLI client |
| `rpc` / `jsonrpc` | Send a JSON-RPC request to the chain |
| `init`, `update`, `version` | Per-chain lifecycle |
| `compress_log`, `remove_log` | Log maintenance |
| `purge` (eco only) | Stop eco and eco-oracle and delete their data; keystore backed up first |

ELA also supports the governance commands `register-bpos`, `activate-bpos`, `unregister-bpos`, `vote-bpos`, `stake-bpos`, `unstake-bpos`, `claim-bpos`, `register-crc`, `activate-crc`, `unregister-crc`, plus `send` and `transfer`. Commands may be written in kebab-case (`register-bpos`) or snake_case (`register_bpos`).

### Security and hardening

EVM RPC and WebSocket endpoints bind to `127.0.0.1`, no signing account is unlocked at startup, and the RPC namespace surface is reduced. Use `firewall` to open the peer/consensus ports (RPC stays private), and `harden` to close any public RPC ports and report which chains still need a restart. For the full security model and the port table, see [SECURITY.md](../../../SECURITY.md).

### Output control

| Flag / variable | Effect |
|---|---|
| `--json` | Machine-readable output for `summary` and `status` |
| `--no-color` or `NO_COLOR=1` | Disable ANSI color |
| `--profile <mainchain|full>` | Override the active profile for one command |

## Running from any directory

`setup` installs a global `node.sh` wrapper in `/usr/local/bin`, so commands work from anywhere. If you installed manually instead, add the script directory to your `PATH` with `set_path`:

```bash
$ ~/node/node.sh set_path
```

This edits your profile file. A re-login is required to make the `PATH` effective.

```
Updating /Path/To/Home/.bash_profile...
INFO: please re-login to make PATH effective
```
