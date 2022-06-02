---
description: WIP...
---

# Compress Log Files

The **compress\_log** will gzip the old log files to save disk space. It will not touch the latest log files, because they are opened by the corresponding daemon programs.

```
$ ./node/node.sh esc compress_log
[ ... the output ... ]
```

If **compress\_log** without specifying chain name, it will do gzip to log files of the installed chains.
