# Installing Programs

The `init` command will download the prebuilt binary package, extract and place the executables in the right place, and write the config files required.

The binary releases are listed for reference. Normally you don't need to manually download them, because `init` commands will download them automatically.

| Chain                     | Binary Packages                                |
| ------------------------- | ---------------------------------------------- |
| Elastos ELA Mainchain     | https://download.elastos.io/elastos-ela        |
| Elastos ESC Sidechain     | https://download.elastos.io/elastos-esc        |
| Elastos ESC Oracle        | https://download.elastos.io/elastos-esc-oracle |
| Elastos EID Sidechain     | https://download.elastos.io/elastos-eid        |
| Elastos EID Oracle        | https://download.elastos.io/elastos-eid-oracle |
| Elastos Arbiter           | https://download.elastos.io/elastos-arbiter    |
| Elastos Carrier Bootstrap | https://download.elastos.io/elastos-carrier    |

The `init` command without specifying the chain program name will process the following programs (chains) in one go.

```bash
$ ~/node/node.sh init
```

As an alternative, you can also run the init command one by one.
