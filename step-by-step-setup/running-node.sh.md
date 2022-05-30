# Running node.sh

Run the script without any arguments to display the usage.

```bash
$ ~/node/node.sh
```

If the output is similar to the following, then the installation is good.

```bash
Usage: node.sh [CHAIN] COMMAND [OPTIONS]
Manage Elastos Node (/home/ubuntu/node) [mainnet]

Available Chains:

  ela
  did
  esc
  esc-oracle
  eid
  eid-oracle
  arbiter
  carrier

Available Commands:

  start
  stop
  status
  upgrade [-y] [-n]
  init
  compress_log
```

The first argument **CHAIN** specifies the chain (program) name, and the second one, **COMMAND** specifies the action to perform.

Please be notified that the CHAIN argument is optional. If it is absent, all chains will be issued COMMAND.

Currently, the only supported Elastos network is MainNet.
