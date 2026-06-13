# Updating node.sh

If you installed the script some time ago, update it to pick up the latest fixes and features.

```bash
$ ~/node/node.sh update_script
```

The older name `script_update` still works as an alias.

`update_script` downloads the latest `node.sh` from Elastos Node for Ubuntu, verifies it against the published `node.sh.sha256` checksum, runs a syntax check, and only then replaces the installed script. After updating, it re-runs the firewall hardening so any newly added RPC ports are closed in the same step. If the checksum does not match, or the download fails the syntax check, the update is refused and the existing script is left untouched.

```bash
Downloading https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh...
OK: checksum verified
OK: /home/ubuntu/node/node.sh updated

Harden - close public RPC exposure
OK: firewall: no public RPC ports were open
OK: all running EVM daemons are bound to 127.0.0.1
```

Run the updated `node.sh` to confirm the new version and review any new command-line options.

```bash
$ ~/node/node.sh version
$ ~/node/node.sh
```

This command updates the operating script only. To update the chain binaries, see [Updating Programs](updating-programs.md).
