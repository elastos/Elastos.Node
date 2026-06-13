# Compress Log Files

The **compress\_log** command gzips the old log files to save disk space. It does not touch the latest log file, because the running daemon still has it open.

```
$ ./node/node.sh esc compress_log
Compressing log files in /home/ubuntu/node/esc/data/geth/logs/dpos...
Compressing log files in /home/ubuntu/node/esc/data/logs-spv...
Compressing log files in /home/ubuntu/node/esc/logs...
```

Run **compress\_log** without a chain name to gzip the log files of every installed chain.

```bash
$ ~/node/node.sh compress_log
```

`setup` adds a cron entry that runs `compress_log` every ten minutes, so on a node prepared with `setup` this happens automatically.

## Viewing logs

To read a chain's most recent log, use **logs**. It prints the tail of the newest log file. Add `-f` to follow it.

```bash
$ ~/node/node.sh logs esc        # tail the most recent esc log
$ ~/node/node.sh logs esc -f     # follow it
$ ~/node/node.sh logs            # defaults to the main chain (ela)
```
