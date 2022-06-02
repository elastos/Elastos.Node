# Stopping Programs

Stopping a single chain or programs:

```bash
$ ~/node/node.sh esc stop
esc         84b1c5e         Stopped
```

Some chains, especially a busy ESC node, may take a pretty long time to fully exist. Issuing multiple stop commands (more than 10 times) to a running ESC node will force it to stop, this may leave a broken database.

_\[TODO: list the scenarios that may need to stop all the programs in one go.]_

Stopping all programs or chains have been installed.

```bash
$ ~/node/node.sh stop
[ ... many messages follow ... ]
```

Different chains and programs share similar output formats after being stopped. So long output omitted.
