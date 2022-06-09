# Program Version and Status

Now you can check all chain **versions** under Available Chains.

```bash
$ ~/node/node.sh
```

```bash
Usage: node.sh [CHAIN] COMMAND [OPTIONS]
Manage Elastos Node (/home/ubuntu/node) [mainnet]

Available Chains:

  ela             v0.8.3
  did             v0.3.2
  esc             84b1c5e
  esc-oracle      0cd7ce2
  eid             cd3d90f
  eid-oracle      1320eba
  arbiter         v0.3.1
  carrier         6.0(20210525)

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

By running the **status** command, you can also track the program **version.** All chains are **Stopped.**

```bash
ela         v0.8.3          Stopped
Disk:       40M
Address:    [ADDRESS]
Public Key: [PUBLIC KEY]

did         v0.3.2          Stopped
Disk:       16M

esc         84b1c5e         Stopped
Disk:       43M

esc-oracle  0cd7ce2         Stopped
Disk:       61M

eid         cd3d90f         Stopped
Disk:       44M

eid-oracle  1320eba         Stopped
Disk:       61M

arbiter     v0.3.1          Stopped
Disk:       19M

carrier     6.0(20210525)   Stopped
Disk:       5.1M
```
