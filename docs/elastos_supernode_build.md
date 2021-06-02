# Elastos Supernode: Build

## Summary

Generally, software build will consumes much more time, but will give you confident that you have the right and precise mapping between your desired code logic and your final product.

## Requirements

- **RAM**: 1 GB
- **HDD**: 8 GB
- **OS**: Ubuntu 16.04 x86_64

## Building steps

```bash
$ cd $HOME
$ git clone https://github.com/elastos/Elastos.ELA.Supernode

$ cd $HOME/Elastos.ELA.Supernode/build
$ ./build.sh

$ ls -l ~/Elastos.ELA.Supernode/release
```

## Use build result

The generated package will contains all the programs and the automatic script. Copy (rsync) it to the target server, extract it to the $HOME folder to use.

