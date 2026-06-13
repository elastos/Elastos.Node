# Operator guide: migrating to Elastos Node for Ubuntu

This guide moves an existing Elastos node from the official `elastos/Elastos.Node` runner (or an earlier version) onto Elastos Node for Ubuntu, and then secures it. It covers two kinds of operator:

- **Council / supernode** operators, who produce blocks and must stay above consensus quorum.
- **Validator / full-node** operators, who run a node without that constraint.

Differences between the two are called out where they matter. If you run the main chain only, you can skip the side-chain steps.

## What migration does, and does not do

| Preserved, never touched | Done for you | Never done automatically |
|---|---|---|
| `ela/keystore.dat` and all keystores | Backs up your old `node.sh` | Restarting a chain daemon |
| All chain data | Verifies the download checksum | Deleting chain data |
| Configuration, including the `WhiteIPList` in `ela/config.json` and `arbiter/config.json` | Writes the deployment profile and a rollback snapshot | Touching SSH or any OS setting |
| Keystore passwords | Closes the public RPC firewall ports | Restarting the ELA main chain |

The install step **restarts nothing**. Your chains keep running and syncing throughout. The only step that restarts a daemon is the side-chain hardening (Step 3), which you control.

## Prerequisites

- Ubuntu, with the node installed in `~/node` and `ela/keystore.dat` present.
- Run as the same user that owns `~/node` (typically the node's normal user).

## Step 1: Install and migrate (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
```

On an existing node this verifies the published checksum, backs up your current `node.sh` to `node.sh.bak.<timestamp>`, swaps in the new script, runs `migrate` (which writes the profile and a rollback snapshot and closes the public RPC firewall ports), and **restarts nothing**. On a fresh box it installs the script and points you to `node.sh setup`.

To review the installer before running it:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh
less install.sh && bash install.sh
```

## Step 2: Verify the migration

```bash
node.sh summary
```

Every chain in your profile should still be running, with heights advancing. Your node is now managed by Elastos Node for Ubuntu, but each daemon is still running under its old flags until you restart it in Step 3.

Council operators: confirm your RPC IP allow-list survived (it does; migration never edits `config.json`):

```bash
grep -c WhiteIPList ~/node/ela/config.json ~/node/arbiter/config.json
```

## Step 3: Harden the side-chain daemons

Hardening is two layers. The **firewall** layer (closing the public RPC ports) was already done in Step 1. This step applies the **daemon** layer: it rebinds RPC and WebSocket to `127.0.0.1` and drops `--unlock` and the `personal` API. That only takes effect when a chain restarts.

Restart each EVM side chain **after it has finished syncing**:

```bash
node.sh esc restart
node.sh pg restart
node.sh eid restart
```

Each restart preserves chain data and brings the chain back bound to `127.0.0.1`. The **ELA main chain is never restarted** by Elastos Node for Ubuntu, so a producer keeps signing throughout.

- **Council operators:** restart a given side chain on only a **few nodes at a time**, staying above two-thirds of the council, and wait for each node's chain to rejoin before doing the next batch. This keeps each side chain's consensus healthy. The main chain is untouched, so DPoS consensus is never at risk.
- **Validator operators:** there is no quorum concern. Restart the side chains whenever each is synced.

If you run the main chain only, there are no side chains to restart and this step is complete.

## Step 4: Verify the node is secure

```bash
node.sh harden
```

`harden` closes any still-open public RPC, oracle, or arbiter port and reports which chains, if any, still need a restart. When it reports no public ports open and all daemons bound to `127.0.0.1`, the node is locked down. Confirm directly:

```bash
ss -tlnp | grep -E ':20636|:20646|:20676'
```

Each RPC port should show `127.0.0.1`, not `0.0.0.0` or `*`. The peer-to-peer and consensus ports (`20338/20339`, `20638/20639`, `20648/20649`, `20678/20679`) remain public, which is correct.

## Step 5: Remove the ECO side chain (when decommissioning)

ECO is decommissioned and is not part of any profile. When you are ready to remove a leftover ECO install:

```bash
node.sh eco purge
```

This is detection-gated: on a node without ECO it reports that there is nothing to remove and changes nothing. On a node with ECO it shows what it will delete and the disk space it will reclaim, requires you to type `eco` to confirm (or `--yes` for unattended runs), stops `eco` and `eco-oracle`, backs up the ECO keystore and password file to `~/eco-keystore-backup-<date>.tar.gz` (and aborts if that backup fails), then deletes `eco/`, `eco-oracle/`, and `eco.txt`. If the data directory was relocated by a symlink, it reports the target so you can reclaim that space manually.

## Staying updated

```bash
node.sh update_script
```

This downloads the latest script, verifies its checksum, syntax-checks it, replaces the installed script, and re-runs the firewall hardening. Run it whenever you want the latest version.

## Rollback

The migration left two restore points:

- `~/node/node.sh.bak.<timestamp>` (your previous script)
- `~/.config/elastos.bak.<timestamp>` (your previous configuration)

To revert the script:

```bash
cp ~/node/node.sh.bak.* ~/node/node.sh
```

Daemons are never stopped during migration, so a rollback does not interrupt them.

## Not covered: SSH and OS hardening

`node.sh` manages the Elastos services only. It never edits `sshd_config` and never closes the SSH port. Securing the host itself (for example, key-based SSH authentication instead of password login) is the operator's responsibility and should be done separately.

## Command summary

```
curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash   # migrate
node.sh summary                 # verify
node.sh esc restart             # harden each side chain after it is synced (council: stagger)
node.sh pg restart
node.sh eid restart
node.sh harden                  # verify + close any remaining public ports
node.sh eco purge               # remove ECO when decommissioning
node.sh update_script           # stay current
```
