# Checking Environments

To verify the Linux distribution, you may invoke:

```bash
$ lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 20.04.4 LTS
Release:	20.04
Codename:	focal

$ uname -a
Linux ip-100-100-100-100 5.13.0-1025-aws #27~20.04.1-Ubuntu SMP Thu May 19 15:17:13 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
```

Please note only Intel x86\_64 Linux is supported.

Installing the dependencies.

```bash
$ sudo apt-get update -y
$ sudo apt-get install -y jq apache2-utils
```
