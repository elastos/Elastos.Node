# Checking Environments

To verify the Linux distribution, you may invoke:

```bash
$ lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 22.04.4 LTS
Release:	22.04
Codename:	jammy

$ uname -a
Linux ip-100-100-100-100 5.15.0-1025-aws #27-Ubuntu SMP Thu May 19 15:17:13 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
```

`node.sh` requires Ubuntu 18.04 or higher on Intel x86\_64. It is tested on 22.04 and 24.04. The ARM64 (aarch64) build is not fully tested and is off by default.

You do not need to install the dependencies by hand. The one-line installer points you to `node.sh setup`, which installs everything (`jq`, `lsof`, `apache2-utils`, `curl`, `openssl`, `ufw`, and the Node.js toolchain for the full profile). See [Installing node.sh](installing-node.sh.md).

To install the core dependencies manually instead:

```bash
$ sudo apt-get update -y
$ sudo apt-get install -y jq lsof apache2-utils curl
```

On startup `node.sh` checks for `jq`, `lsof`, and `rotatelogs` (from `apache2-utils`) and reports the install command for any that are missing.
