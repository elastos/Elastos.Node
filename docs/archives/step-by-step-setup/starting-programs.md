# Starting Programs

Starting a single program.

```bash
$ ~/node/node.sh ela start
Starting ela...
ela         v0.9.5          Running
...
```

Please note that it takes some time to validate the database.

Checking program status.

```bash
$ ~/node/node.sh ela status
ela         v0.9.5          Running
Disk:       360M
PID:        120480
RAM:        1486252K
Uptime:     15:38
#Files:     83
TCP Ports:  IPv4_*:20338 IPv6_*:20338 IPv4_*:20339 IPv6_*:20339 IPv4_*:20336 
#TCP:       14
#Peers:     8
Height:     173154
```

| Status Item | Description                                         |
| ----------- | --------------------------------------------------- |
| Disk        | The disk usage in human-readable format             |
| PID         | Process id                                          |
| RAM         | The memory usage in human-readable format           |
| Uptime      | How long the program has been running               |
| #Files      | How many file descriptors opened                    |
| TCP Ports   | The TCP ports listened                              |
| #TCP        | How many tcp connections                            |
| #Peers      | How many peers connected                            |
| Height      | The height of the chain                             |
| Address     | The ELA address of the first account in keystore    |
| Public Key  | The ELA public key of the first account in keystore |

Please note that not all chains/programs have the same set of Status Items. For example, if a program does not open a TCP port, its status output will not have TCP-related metrics. If a program is not a chain, for example esc-oracle, the status will not have peer and height fields.

### Starting all programs

Running the **start** command without a chain/program name starts every chain in the active profile, in a predefined order.

```bash
$ ~/node/node.sh start
[ ... many messages follow ... ]
```

To check process status, resource usage, and other metrics, use the labeled `status` block, or `summary` for a one-line-per-chain table of state, height, peers, and sync:

```bash
$ ~/node/node.sh summary
[ ... one row per chain ... ]
```

For an exit-code check suitable for scripts or cron, use `health`. It exits `0` when every chain in the profile is healthy and non-zero otherwise:

```bash
$ ~/node/node.sh health
```

### Closing the public RPC ports

After the first start, run `harden` to close public access to the RPC, oracle, and arbiter ports. It closes the firewall ports immediately (restarting nothing) and reports any EVM side chain that still needs a restart to rebind its RPC to `127.0.0.1`:

```bash
$ ~/node/node.sh harden
```

The EVM JSON-RPC and WebSocket endpoints bind to `127.0.0.1` (localhost only) on this version, so they are not reachable from the network. See [SECURITY.md](../../../SECURITY.md) for the full port table and the two-layer hardening model.

### Auto-start when OS Reboots

`setup` already installs an `@reboot` autostart entry. To configure it by hand, open the user-level crontab editor. You may be asked to select an editing program.

```bash
$ crontab -e
```

Append the following entry, then save and exit. It starts every chain in the active profile on reboot.

```bash
@reboot ~/node/node.sh start
```

To start only specific chains instead, add one entry per chain.

```bash
@reboot ~/node/node.sh esc start
@reboot ~/node/node.sh eid start
@reboot ~/node/node.sh pg start
```

Check the current crontab by running:

```bash
$ crontab -l
```
