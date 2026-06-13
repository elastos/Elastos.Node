# Backup and Uninstall

## Backup

_The importance of backing up an Elastos blockchain node._

The table lists some of the important files.

| Important file                    | Description                |
| --------------------------------- | -------------------------- |
| `$HOME/node/ela/keystore.dat`     | ELA keystore file          |
| `$HOME/node/esc/keystore.dat`     | ESC keystore file          |
| `$HOME/node/eid/keystore.dat`     | EID keystore file          |
| `$HOME/node/pg/keystore.dat`      | PG keystore file           |
| `$HOME/node/arbiter/keystore.dat` | Arbiter keystore file      |
| `$HOME/.config/elastos/ela.txt`   | ELA keystore password file |
| `$HOME/.config/elastos/esc.txt`   | ESC keystore password file |
| `$HOME/.config/elastos/eid.txt`   | EID keystore password file |
| `$HOME/.config/elastos/pg.txt`    | PG keystore password file  |

Keep these files in offline cold backup. The keystore files and their password files are what control the node identity and any funds.

## Uninstall

To stop every chain and remove the installation, use **uninstall**:

```bash
$ ~/node/node.sh uninstall
```

It stops all daemons, backs up `ela/keystore.dat` to `~/keystore.dat.bak.<timestamp>` first, then removes the per-chain directories (`ela`, `esc`, `eid`, `pg`, the oracles, `arbiter`, `extern`) and `~/.config/elastos`. Chain data is deleted. The command runs only in an interactive terminal and requires you to type `DELETE` to confirm.

`node.sh` itself is left in place; remove it manually if you no longer need it:

```bash
$ rm ~/node/node.sh
```

To remove only the decommissioned ECO side chain (when present), use `node.sh eco purge` instead. It stops `eco` and `eco-oracle`, backs up the ECO keystore, and deletes only the ECO data. See [the migration guide](../MIGRATION.md) for details.

If you are unsure about any deletion, consult the developer. Think twice before any destructive operation.
