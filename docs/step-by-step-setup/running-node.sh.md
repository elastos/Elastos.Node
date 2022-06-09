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

  ela             N/A
  did             N/A
  esc             N/A
  esc-oracle      N/A
  eid             N/A
  eid-oracle      N/A
  arbiter         N/A
  carrier         N/A

Available Commands:

  start           Start chain daemon
  stop            Stop chain daemon
  status          Print chain daemon status
  client          Run chain client
  jsonrpc         Call JSON-RPC API
  update          Install or update chain
  init            Install and configure chain
  compress_log    Compress log files to save disk space
```

Currently, the only supported Elastos network is MainNet.

The first argument **CHAIN** specifies the chain (program) name.

The second one, **COMMAND** specifies the action to perform.

The N/A means a chain has not been installed.

Please be notified that the CHAIN argument is optional. If it is absent, all chains will be issued COMMAND.
