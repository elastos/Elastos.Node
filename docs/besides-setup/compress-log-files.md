---
description: WIP...
---

# Compress Log Files

The **compress\_log** will gzip the old log files to save disk space. It will not touch the latest log files because the corresponding daemon programs open them.

```
$ ./node/node.sh esc compress_log
Compressing log files in /home/ubuntu/node/esc/data/geth/logs/dpos...
Compressing log files in /home/ubuntu/node/esc/data/logs-spv...
Compressing log files in /home/ubuntu/node/esc/logs...
```

If **compress\_log** without specify the chain name, it will do gzip to log files of the installed chains.
