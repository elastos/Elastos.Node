# Installing Programs

The `init` command will download the prebuilt binary package, extract and place the executables in the right place, and write the config files required.

The binary releases are listed for reference. Normally you don't need to manually download them, because `init` commands will download them automatically.

| Chain                     | Binary Packages                                |
| ------------------------- | ---------------------------------------------- |
| Elastos ELA Mainchain     | https://download.elastos.io/elastos-ela        |
| Elastos ESC Sidechain     | https://download.elastos.io/elastos-esc        |
| Elastos ESC Oracle        | https://download.elastos.io/elastos-esc-oracle |
| Elastos EID Sidechain     | https://download.elastos.io/elastos-eid        |
| Elastos EID Oracle        | https://download.elastos.io/elastos-eid-oracle |
| Elastos PG Sidechain      | https://download.elastos.io/elastos-pg         |
| Elastos PG Oracle         | https://download.elastos.io/elastos-pg-oracle  |
| Elastos Arbiter           | https://download.elastos.io/elastos-arbiter    |

The decommissioned ECO and PGP side chains are not installed by this script. A leftover ECO installation from the upstream runner can be stopped and removed with `node.sh eco purge`.

## Choosing a profile

This runner installs the set of programs defined by the active deployment profile:

| Profile     | Installs                                                              |
| ----------- | -------------------------------------------------------------------- |
| `mainchain` | `ela` only                                                           |
| `full`      | `ela`, `esc`, `eid`, `pg`, the three oracles, and `arbiter`          |

Set the profile before installing:

```bash
$ ~/node/node.sh profile set full      # or: mainchain
```

The `init` command without specifying the chain program name will process every program in the active profile in one go.

```bash
$ ~/node/node.sh init
```

As an alternative, you can also run the init command one by one. The per-program pages that follow show each `node.sh <chain> init` command individually.

After the programs are installed, start them and check their state:

```bash
$ ~/node/node.sh start
$ ~/node/node.sh summary
$ ~/node/node.sh health
```
