# Program Version and Status

Running `node.sh` with no arguments prints the command reference and the running script version.

```bash
$ ~/node/node.sh
```

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
```

To list the installed chain binary **versions**, run `version`:

```bash
$ ~/node/node.sh version
Elastos Node for Ubuntu v1.1.0

  ela     v0.9.5
  esc     84b1c5e
  eid     cd3d90f
  pg      4baf3a1
```

## status: the labeled block

`status` prints the familiar per-chain labeled block for every chain in the active profile. Each field is on its own line. This is the detailed view.

```bash
$ ~/node/node.sh status
ela         v0.9.5          Stopped
Disk:       40M
Address:    [ADDRESS]
Public Key: [PUBLIC KEY]

esc         84b1c5e         Stopped
Disk:       43M

eid         cd3d90f         Stopped
Disk:       44M

pg          4baf3a1         Stopped
Disk:       42M

arbiter     v0.3.1          Stopped
Disk:       19M
```

A single chain can be queried the same way, and `--json` returns machine-readable output:

```bash
$ ~/node/node.sh ela status
$ ~/node/node.sh esc status --json
```

When `status` output is not a terminal (for example, piped into a file), it falls back to the full field dump so existing parsers keep working.

## summary: the one-line table

`summary` (alias `ps`) prints one row per chain in the active profile: state, height, peers, and a health glyph. It is the quick fleet glance. Height and peers come from each chain's RPC over loopback, so they read `-` for services that have neither and `?` if a running chain's RPC is briefly unreachable.

```bash
$ ~/node/node.sh summary

  Elastos node   profile: full
  CHAIN        STATE     HEIGHT        PEERS  HEALTH
  -------------------------------------------------------
  ela          running   173154        8      ●
  esc          running   1820461       6      ●
  esc-oracle   running   -             -      ●
  eid          running   1402233       5      ●
  eid-oracle   running   -             -      ●
  pg           running   903118        4      ●
  pg-oracle    running   -             -      ●
  arbiter      running   -             -      ●
  -------------------------------------------------------
  ● healthy   ◐ syncing/attention   ○ stopped
  ✓ 8/8 running, all healthy
```

Add `--json` for a machine-readable array:

```bash
$ ~/node/node.sh summary --json
```

Not every chain reports the same fields. A service such as `esc-oracle` has no height or peer count, so those columns show `-`.
