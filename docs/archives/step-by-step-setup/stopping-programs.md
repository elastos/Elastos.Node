# Stopping Programs

Stopping a single chain or program:

```bash
$ ~/node/node.sh esc stop
esc         84b1c5e         Stopped
```

Some chains, especially a busy ESC node, may take a long time to exit fully. Issuing multiple stop commands (more than ten times) to a running ESC node forces it to stop. This may leave a broken database.

Stopping all programs or chains in the active profile.

```bash
$ ~/node/node.sh stop
[ ... many messages follow ... ]
```

Different chains and programs share similar output after being stopped, so the long output is omitted here.

### Restarting

`restart` stops and starts each chain in the active profile, one at a time. It **excludes the ELA main chain by default**, because restarting it would interrupt council consensus. Re-run with `--force` to include `ela`.

```bash
$ ~/node/node.sh restart            # every chain except ela
$ ~/node/node.sh restart --force    # include ela as well
```

A single chain can always be restarted directly, for example `node.sh esc restart`. The same guard applies: `node.sh ela restart` refuses unless `--force` is given.
