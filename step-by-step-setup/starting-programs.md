# Starting Programs

Starting a single program.

```bash
$ ~/node/node.sh ela start
Starting ela...
ela         v0.8.3          Running
...
```

Please note that it takes some time to validate the database.

Checking program status.

```bash
$ ~/node/node.sh ela status
ela         v0.8.3          Running
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

| Status Item | Description                               |
| ----------- | ----------------------------------------- |
| Disk        | The disk usage in human-readable format   |
| PID         | Process id                                |
| RAM         | The memory usage in human-readable format |
| Uptime      | How long the program has been running     |
| #Files      | How many file descriptors opened          |
| TCP Ports   | The TCP ports listened                    |
| #TCP        | How to many tcp connections               |
| #Peers      | How many peers connected                  |
| Height      | The height of the chain                   |

Please note that not all chains/programs have the same set of Status Items. For example, if some programs don't open a TCP port, its status output will not have TCP-related metrics. If some program is not a chain, for example, ESC-Oracle, the status will not have Peer and Height related.

### Starting all programs

By running the **start** command without chain/program name. All installed chains/programs will be started in a predefined order.

```bash
$ ~/node/node.sh start
[ ... many messages follow ... ]
```

If you wish to check processes status, the resources usage and other metrics.

```
$ ~/node/node.sh status
[ ... many messages follow ... ]
```

### Auto-start when OS Reboot

Enter the command to open the user-level crontab editor. You may be asked to select an editing program.&#x20;

```bash
$ crontab -e
```

Append the following entry to the existing crontab, save and exit.

```bash
@reboot ~/node/node.sh start
```

You may prefer to add multiple start commands if you have not install all the components of Elastos blockchain.

```
@reboot ~/node/node.sh esc start
@reboot ~/node/node.sh eid start
```

Checking the current crontab by running:

```bash
$ crontab -l
```
