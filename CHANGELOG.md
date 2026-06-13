# Changelog

All notable changes to this project are documented in this file. Releases are tagged `vMAJOR.MINOR.PATCH`.

## v1.1.0 - First stable release

Validated end to end on a live node: one-line migration, the read views, the per-chain hardening restart (rebinding RPC to `127.0.0.1` with `--unlock` and `personal` removed), the firewall hardening, and ECO removal. This release consolidates the `1.0.0-rc` series into a stable tag.

### Highlights
- **Security.** Loopback-only EVM RPC, no remotely-unlockable account, reduced RPC surface, automatic firewall close of the EVM RPC/WebSocket and oracle ports on `migrate` and `update_script`, and a status command that cannot crash a syncing daemon. The authenticated ELA and arbiter RPC ports are left open for read-only monitors (gated by `WhiteIPList` / RPC user/pass).
- **Operations.** One-line installer, deployment profiles (main chain only or full stack), `summary`/`health`/`status`/`logs`, staged `migrate`, `harden`, and `eco purge`.
- **Compatibility.** Every command from the original Elastos.Node runner continues to work; the directory layout, keystores, and chain data are unchanged, so it is a drop-in replacement.

See the entries below for the full path from `v0.1.0`.

## v1.0.0-rc.10 - update_script re-execs the new harden

### Fixed
- After a self-update, `update_script` now re-execs the just-downloaded script (`node.sh harden`) instead of calling the hardening code still loaded in memory. A running shell never reloads its own file, so when an update adds new ports to close (as rc.9 did for the oracle/arbiter ports), the auto-harden during that same update would otherwise use the previous port list and miss them. Re-execing the new script closes the newly-added ports in the same step. Falls back to the in-memory function if the re-exec is unavailable.

## v1.0.0-rc.9 - harden also closes the oracle and arbiter RPC ports

### Changed
- `harden` (and the automatic firewall close in `migrate`/`update_script`) now also closes the crosschain oracle HttpJsonPorts (`20632`, `20642`, `20652`, `20672`) and the arbiter RPC port (`20536`), in addition to the EVM and ela RPC/WS ports. A live audit found these bound to `0.0.0.0` and open in the firewall on an upstream node, even though they are local-only services (the local geth and arbiter reach them over loopback). The arbiter P2P port (`20538`) and all chain P2P/consensus ports stay open.

## v1.0.0-rc.8 - Automatic firewall hardening, and cleaner status

### Added
- `harden` command. It closes the host firewall on the RPC and WebSocket ports (`20336`, `20635/6`, `20645/6`, `20655/6`, `20675/6`) and reports which running EVM daemons are still bound to `0.0.0.0` and so need a restart to rebind to `127.0.0.1`. The firewall close is immediate, reversible, idempotent, and restarts nothing; local loopback access is unaffected.
- `migrate` and `update_script` now run the firewall close automatically. Moving onto Elastos Node for Ubuntu, or updating it, immediately closes the public RPC exposure rather than leaving it open until the operator restarts the chains. The daemon rebind still requires a restart, which `harden` and the migration output both call out.

  This addresses the gap where swapping the script alone changed nothing about the live exposure: the firewall layer now closes on update, and the restart layer is clearly flagged.

### Changed
- `status` and `<chain> status` are restored to the classic upstream labeled block: one aligned field per line, all fields, no added header or footer. The earlier compact and trimmed variants were removed in favor of the format operators preferred. `summary` remains the one-line-per-chain table.

## v1.0.0-rc.7 - Config lookup independent of the script filename

### Fixed
- The network config path was derived from the script's filename (`~/.config/elastos/<script-basename>.json`). When the script was run under any name other than `node.sh` (for example `node.sh.new` during a migration rehearsal), it looked for a config that does not exist, then prompted for the network and wrote a stray config file. The documented `migrate --dry-run` rehearsal is meant to be read-only and was not. The config path is now fixed to `~/.config/elastos/node.json` (the Elastos convention) regardless of the script's filename, so running the script under any name finds the existing config and changes nothing.

## v1.0.0-rc.6 - One-line installer

### Added
- `install.sh`: a single command installs the script and, on a host that already runs a node, migrates it onto Elastos Node for Ubuntu.

  ```
  curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
  ```

  It verifies the published SHA-256 before installing, backs up an existing `node.sh`, and never touches keystores or chain data. On a fresh host it installs the script and points to `node.sh setup`; on an existing node it runs `migrate`, which restarts nothing. This replaces the previous manual download-and-rename sequence.

### Changed
- After a successful `migrate`, the script now prints how to keep Elastos Node for Ubuntu updated (`node.sh update_script`).
- Documentation leads with the one-line installer for first-time migration; the manual step-by-step procedure remains documented for operators who prefer it.

## v1.0.0-rc.5 - Simplification

Subtraction-only release. No command an operator uses changes behavior.

### Removed
- `status --pretty` and its renderer. The flag was unreachable dead code for six releases before v1.0.0-rc.2 wired it, which indicates it was not missed; `summary` covers the glance view and `status` the detail view. The flag now falls back to the standard labeled status, matching how the upstream script treats unknown status flags. The hot-wallet reward indicator remains visible in `status` and in the `--json` output.
- The `evm_sync_detail` helper, whose only caller was the removed renderer.

### Changed
- `help` is reorganized into tiers: the five daily commands (`start`, `stop`, `summary`, `status`, `logs`, `health`) come first, followed by setup, management, and per-chain sections. Aliases (`up`, `down`, `ps`, `rpc`) are listed on a single line instead of duplicating command rows. `migrate` is now listed in `help` (it was previously only documented in the README).
- Per-chain help received the same treatment.

## v1.0.0-rc.4 - Removal command for the decommissioned ECO chain

### Added
- `node.sh eco purge`: stops `eco` and `eco-oracle` and deletes their data on nodes migrated from the upstream runner that still carry the decommissioned ECO side chain. Detection-gated: on a node without ECO the command reports that there is nothing to remove and changes nothing. Before deleting, the ECO keystore and its password file are backed up to `~/eco-keystore-backup-<timestamp>.tar.gz`; the backup must succeed or nothing is deleted. Deletion requires typing `eco` to confirm, or `--yes` for unattended use; an unattended run without `--yes` is refused. A relocated (symlinked) data directory is reported so its target can be reclaimed manually.
- `migrate` detects a leftover ECO installation and points to `eco purge`.

### Changed
- `migrate --apply` no longer restarts a running ECO daemon to harden it; it leaves ECO untouched and suggests `eco purge`, since removal rather than hardening is the appropriate action for a decommissioned chain.
- `purge` is accepted only for the `eco` chain; on any other chain it exits with an error.

## v1.0.0-rc.3 - Warn instead of refuse on a missing cold reward address

### Changed
- A mining side chain without a cold reward address now starts (matching upstream behavior) instead of refusing to start. Every such start prints a prominent red warning stating that block rewards will credit the node's local hot account, together with the `reward set` command. The refusal policy introduced in v0.2.0 proved too strict for operators who accept mining to the local account.
- The refusal-based guards tied to the old policy are removed: `update` no longer blocks on a missing reward address, `restart` no longer declines to stop such a chain, `migrate --apply` no longer skips it, and the bulk `start` no longer collects refused chains (nothing refuses anymore, which also removes the arbiter skip case added in v1.0.0-rc.2).
- Internals: `require_cold_miner` and `guard_cold_for_update` are replaced by `has_cold_miner` (silent predicate) and `warn_hot_miner` (red warning, never blocks).

## v1.0.0-rc.2 - Final compatibility review fixes

A five-reviewer compatibility audit of v1.0.0-rc.1 against the upstream runner confirmed command-surface, start-flag, init/update, and status-output parity, and found the following defects, all fixed and covered by isolated function tests.

### Fixed
- **Critical: `start`, `up`, `restart --force`, and the `@reboot` autostart refused to start the ELA main chain on every initialized node.** The cold-reward-address gate treated the ELA keystore password file as evidence of a mining configuration and demanded a `miner_address.txt` that never exists for ELA. The gate is now scoped to the EVM side chains only; ELA, the oracles, and the arbiter are never gated. Introduced in v0.9.7; the direct `ela start` command was unaffected.
- `start` no longer hangs when side chains are refused for a missing cold reward address. The arbiter start loop (inherited from upstream) respawns until the arbiter stays up, which never happens while its dependencies are down; `start` now skips the arbiter in that case, reports it, and exits non-zero.
- `--profile` given without a value caused an infinite busy loop in the argument parser. It now exits with an error message.
- `remove_log` failed with `command not found` on a full-profile node: `pg-oracle_remove_log` did not exist. The function slot held a dead duplicate of `pg-oracle_update` operating on the pgp-oracle directories (inherited from upstream, where the same defect exists). The dead duplicate was replaced with a correct `pg-oracle_remove_log`.
- `health` reported `healthy` for a chain whose daemon was running but whose RPC was unreachable. That state now reports `running (rpc unreachable)` and exits non-zero.
- `status --pretty` was advertised but not wired to a handler; it now renders the health-first view.
- The single-chain `status` in the piped (non-TTY) classic path no longer discards stderr, matching upstream diagnostics for automation that captures both streams.

### Changed
- `eco` and `eco-oracle` are directly addressable again (`node.sh eco stop`, `status`, `logs`), so an operator upgrading a host with a running ECO daemon retains managed control of it. ECO remains excluded from every profile and from all bulk commands.
- `setup` now installs the 10-minute `compress_log` cron entry in addition to the `@reboot` autostart, and its deduplication recognizes both the absolute-path and the upstream tilde-path entry forms, preventing duplicate `@reboot` entries.

## v1.0.0-rc.1 - Documentation release

Release candidate for v1.0.0. No functional script changes other than the version string.

### Documentation
- Rewrote `README.md` as a complete reference: installation, quick start, deployment profiles, full command tables, security model, migration, updating, file locations.
- Rewrote `SECURITY.md`: default posture, RPC bind override, remote-access guidance, full port table, vulnerability reporting.
- Added `docs/COMPARISON.md`: a feature and security comparison against the original `elastos/Elastos.Node` runner.
- Added `docs/MIGRATION.md`: the step-by-step procedure for moving an existing installation onto Elastos Node for Ubuntu, including verification and rollback.
- Normalized this changelog to a consistent, neutral format.

### Status
- Feature-complete against the project's security and operations plans. Field validation on a clean Ubuntu host is the remaining step before v1.0.0.

## v0.9.8 - Review fixes for v0.9.7

Seven issues found in a code review of v0.9.7, each verified with isolated function tests.

### Fixed
- `FORCE_ELA` is reset at startup. Previously an exported `FORCE_ELA=1` in the environment could silently re-enable main-chain restarts; now only the `--force` flag enables them.
- `restart` aggregates per-chain results and exits non-zero if any chain failed, matching the behavior of `start`.
- Interactive prompts (profile, network, orphan-config) read piped input when present and fall back to a safe default only at end of input. This restores correct behavior for piped invocations of `init`.
- `EVM_RPC_BIND` is validated, and can be persisted in `~/.config/elastos/evm_rpc_bind`. An invalid value falls back to `127.0.0.1`.
- The RPC bind notice is printed only after the daemon is confirmed running.
- The `sponsors` download aborts a stalled transfer after approximately 30 seconds (`--speed-limit` / `--speed-time`) instead of waiting for the full timeout.

### Changed
- Added the `EVM_CHAINS` constant and the `is_evm_chain`, `evm_rpc_bind`, and `guard_cold_for_update` helpers, replacing duplicated chain lists and guards.

## v0.9.7 - Compatibility audit fixes

A compatibility audit against the official `elastos/Elastos.Node` confirmed that a file swap is a zero-downtime operation, and identified the following issues, fixed in this release.

### Safety
- `restart` and `ela restart` no longer restart the ELA main chain by default, since that interrupts council consensus. The `--force` (or `--include-ela`) flag overrides this.
- `restart` and `update` check the cold reward address before stopping a mining side chain. A chain that could not be restarted is left running, with a message.
- `migrate --apply` covers the eco and pgp chains in addition to esc, eid, and pg.
- Migration rollback snapshots use a unique suffix to avoid same-second collisions.

### Visibility
- Every EVM chain start prints a one-line notice of the RPC/WS bind address.
- `start` collects side chains that refused to start (missing cold reward address) and exits non-zero with a summary.

### Compatibility
- New `EVM_RPC_BIND` environment variable (default `127.0.0.1`) for deliberately serving RPC on another interface. The removal of `--unlock` and the `personal` namespace applies regardless of the bind address.
- The `sponsors` download and the version probe have `curl` timeouts, so `ela start` cannot hang on a network failure.
- `status` falls back to the full classic output when not attached to a TTY, so existing scripts that parse the old per-chain output keep working.

### Automation
- Interactive prompts (profile, network, orphan-config, `uninstall`, `migrate --apply`) are TTY-guarded: in a non-interactive shell they take the safe default or refuse cleanly. `uninstall` refuses to delete unattended.

## v0.9.6 - Labeled status view

### Changed
- `node.sh status` shows each chain's status as a labeled block, one field per line, aligned. Retained fields: version, state, `Address`, `Public Key`, `Height`, `#Peers`, `Uptime`, `RAM`, `Disk`, and the governance block (`BPoS Name / State / Staked / Votes / Rewards`, `CRC Name / State`). Removed fields: `Balance`, `PID`, `#Files`, `#TCP`, and the TCP/UDP port lists.
- `node.sh <chain> status --verbose` shows the complete dump, including the removed fields. `node.sh summary` / `ps` remains the one-row-per-chain view.

## v0.9.5 - Governance information in status

### Changed
- The ELA status includes the governance line (BPoS or CRC name, state, votes, rewards), the address, and the full public key. An unregistered node is reported as such, with a pointer to `register-bpos` / `register-crc`.
- Side chains show the configured reward address. The arbiter shows its bridge heights (spv, esc, eid, pg).

## v0.9.4 - Status cards

### Changed
- `node.sh status` was redesigned as a compact per-chain card showing health verdict, version, peers, height, uptime, RAM, and disk. Superseded by the labeled view in v0.9.6.
- The three status views are layered: `summary` / `ps` (one row per chain), `status` (per-chain detail), `status --verbose` (complete dump).

## v0.9.3 - Global command

### Added
- `setup` installs a wrapper at `/usr/local/bin/node.sh`, so commands can be run from any directory without a path prefix. `SCRIPT_PATH` resolves through symlinks and wrappers to locate the installation directory.

### Changed
- `node.sh status` defaults to the summary view (superseded by v0.9.6). The detailed output remains available via `--verbose`.

## v0.9.2 - Initialization and start guards

### Fixed
- `init` detects an orphaned keystore password (`~/.config/elastos/<chain>.txt` without a matching keystore, typically left behind by removing `~/node` without clearing the configuration) and offers to clear it so initialization can proceed.
- `start` refuses to launch an uninitialized `ela` (no `config.json`) and directs the operator to `init`, instead of starting a daemon that cannot run.
- Post-`setup` instructions print full paths and the `reward set` command.

## v0.9.1 - Automatic sponsors file

### Fixed
- The ELA main chain requires a `sponsors` file (a height-to-sponsor lookup) to validate blocks past the RecordSponsor fork at approximately block 1,801,550. The upstream runner does not download this file, so fresh nodes stall at that height. `ela_start` now downloads the file automatically when missing (mainnet only), from the distribution matching the installed binary version, and prints a warning if the download fails. The download is one-time, approximately 28 MB.

## v0.9.0 - Staged hardening apply

### Added
- `node.sh migrate --apply [--yes]`: applies the hardened RPC binding with minimal downtime. Restarts only side chains running with stale flags, one at a time, and waits for each to return on `127.0.0.1` (verified from the live process command line) before restarting the next. The ELA main chain is never restarted. Chains without a cold reward address are skipped and reported. The procedure stops on the first failure.

## v0.8.5 - Migration command

### Added
- `node.sh migrate [--dry-run]`: moves an existing installation (an earlier version, or the official `elastos/Elastos.Node`) onto Elastos Node for Ubuntu.
  - Detects the source installation from the profile file and running processes.
  - Preserves the ELA keystore, chain data, and configuration. Aborts if `keystore.dat` is missing or `node.json` is invalid.
  - Infers and writes the deployment profile for an upstream installation.
  - Warns if a mining chain has no cold reward address.
  - Writes rollback snapshots (`node.sh.bak.<timestamp>`, `~/.config/elastos.bak.<timestamp>`).
  - Never restarts processes; it prints a staged one-chain-at-a-time restart plan instead.
  - `--dry-run` previews all of the above and changes nothing.

## v0.8.4 - Summary output

### Changed
- `summary` / `ps` print a glyph legend and an attention line naming the chains that need attention, for example `attention: esc(no-peers) eid(syncing) pg(stopped)`.
- Service rows (oracles, arbiter) show `-` for height and peers, since they have no block height.

## v0.8.3 - Help system

### Fixed
- `help` lists every command. The previous help only listed chain names; `summary`, `health`, `profile`, `setup`, `reward`, and the modern verbs were not discoverable.
- Per-chain help shows the commands that exist for that chain. The upstream `ela` help advertised `watch` and `mon`, which do not exist; `pg` had no help.
- `node.sh <chain>` with no command prints help and exits non-zero (previously exit 0). Unknown commands and chains also exit non-zero, with suggestions.

## v0.8.2 - Modern command layer

All additions are aliases over the existing dispatch; every upstream command continues to work unchanged.

### Added
- Global: `up` (= `start`), `down` (= `stop`), `ps` (= `summary`), `restart`, `logs [<chain>] [-f]`, `version` / `--version` / `-v`, `reward [set <0x..>]`, `uninstall` (stops processes, backs up the keystore, removes the installation after typed confirmation).
- Per-chain: `up`, `down`, `restart`, `logs [-f]`, `rpc` (= `jsonrpc`), `version`.
- Kebab-case command names are accepted everywhere (`register-bpos` is equivalent to `register_bpos`).

## v0.8.1 - Arbiter initialization fix

### Fixed
- `arbiter_init` required the decommissioned `eco-oracle` and `pgp-oracle` services and listed ECO in its cross-chain `SideNodeList`, causing initialization to fail on a full-stack node. The preflight checks and both the mainnet and testnet `SideNodeList` configurations now contain only ESC, EID, and PG.

## v0.8.0 - Turnkey setup

### Added
- `node.sh setup`: prepares a fresh Ubuntu host and initializes the node in one command: installs dependencies, adds a 16 GB swap file, configures the firewall, enables autostart on reboot, then runs `init`. Profile-aware, idempotent, and asks before making system changes.
- `node.sh firewall`: opens the peer and consensus ports for the active profile (mainchain: `20338`, `20339`; full: additionally `20638`, `20639`, `20648`, `20649`, `20678`, `20679`). RPC and WebSocket ports are not opened; they bind to `127.0.0.1`.

## v0.7.1 - Single-invocation first run

### Fixed
- The first invocation of any command previously wrote `~/.config/elastos/node.json` and exited, requiring the command to be run a second time. It now writes the configuration and continues with the requested command.

## v0.7.0 - Oracle start verification

### Added
- The post-start verification covers the oracle services. `start` verifies that every chain and oracle process remains running, and reports a process that exited immediately, with the last lines of its log.

## v0.6.0 - Chain start verification

### Added
- After `start`, each chain daemon is verified to still be running. A daemon that exited on launch is reported immediately with the last lines of its log, instead of being discovered later through a stopped status.

## v0.5.0 - Error-aware status values

### Fixed
- The per-chain `status` distinguishes RPC errors from real zero values. A height or peer count from an unreachable RPC shows `N/A`; a genuine `0` still shows `0`. Hex values are parsed with a dedicated converter, replacing arithmetic expansion that could misparse hex and leading-zero values. Applies to the esc, eid, and pg heights and peer counts, and to the ela peer count.

## v0.4.0 - Health checks

### Added
- `node.sh health` and `node.sh <chain> health`: a one-line verdict per chain with a meaningful exit code (0 healthy; non-zero if stopped, syncing, or without peers). `node.sh health` exits non-zero if any chain in the active profile is unhealthy, which makes it usable from cron and alerting.
- `<chain> status --pretty` shows a sync-progress line (`current / highest (NN%)`) while a chain is catching up.

## v0.3.0 - Summary dashboard and JSON output

### Added
- `node.sh summary` shows height and peers per chain, with sync-aware and peer-aware health indicators.
- `node.sh <chain> status --pretty` reports height, peers, sync state, and flags a reward address that belongs to the node's local keystore.
- `--json` output: `node.sh summary --json` (array) and `node.sh <chain> status --json` (object), each entry `{chain, installed, running, height, peers, sync, reward}`.

### Fixed
- Status RPC calls are bounded with `curl --max-time 3`, so a status query cannot hang. Hex parsing uses a dedicated converter. An unreachable RPC is shown as unknown rather than `0`.

## v0.2.0 - Verified self-update and cold rewards

### Security
- Self-update targets this repository instead of upstream, verifies the published SHA-256 checksum (`node.sh.sha256`), and runs `bash -n` on the download before installing. An update can no longer revert the hardening.
- A mining chain refuses to start unless `<chain>/data/miner_address.txt` contains a valid address, so block rewards cannot fall back to the node's local account.

### Added
- `node.sh summary`: one row per chain in the active profile, with health indicators and a running/stopped count.
- `node.sh <chain> status --pretty`: a health verdict above the standard status.
- Color output respects `NO_COLOR` and non-TTY contexts; `--no-color` flag.
- Suggestions for misspelled chain and command names.
- Guided `init`: asks for the deployment profile on first run and persists the choice.

## v0.1.0 - Initial hardened release

First release, building on `elastos/Elastos.Node`.

### Security
- All EVM side-chain start paths bind `--rpcaddr` and `--wsaddr` to `127.0.0.1` (previously `0.0.0.0`).
- Removed `--unlock` and `--allow-insecure-unlock`. Block sealing is unaffected: consensus signs with the dedicated PBFT/ELA keystore, not the EVM account.
- Reduced `--rpcapi` to `eth,net,web3,txpool,pbft` (mining) and `eth,net,web3,txpool` (follower), removing `personal`, `db`, `miner`, and `admin`.
- Net effect: an unauthenticated `eth_sendTransaction` path reachable over public RPC no longer exists.

### Fixed
- `ela status` no longer calls `dposv2rewardinfo` on a syncing node. That call can panic the ELA daemon during synchronization. It is gated on a sync check and reports `N/A` until the node is synced.

### Added
- Deployment profiles `mainchain` and `full`, persisted to `~/.config/elastos/profile`, with a `--profile <p>` override and a `profile [set <p>]` command.
- `help` / `-h` / `--help` top-level command.

### Removed
- The decommissioned ECO side chain and `eco-oracle` are removed from dispatch and from all profiles.
