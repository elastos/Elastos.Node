# Build from the Source Code

## Summary

This build script helps user to generate a bundle package of all the required to setup an Elastos node. It will take 10 to 15 minutes in the [cloud build service](https://github.com/elastos/Elastos.Node/actions).

## System requirements

* **RAM**: 2 GB
* **HDD**: 8 GB
* **OS**: Ubuntu 18.04 x86\_64

## Building steps

```bash
$ cd $HOME
$ git clone https://github.com/elastos/Elastos.Node
$ cd Elastos.Node
$ ./build.sh
[ ... many outputs ... ]
```

## Build result

The generated package contains all the programs and the automatic script to operate a node. Copy (rsync) it to the target server, and extract it to the $HOME folder.

**List** the build results.

```bash
$ ls -1 ~/Elastos.Node/release/linux-x86_64
20220610-141947
```

Dive into the build result **folder**.

```bash
$ cd ~/Elastos.Node/release/linux-x86_64/20220610-141947
```

**Transfer** the tarball to the target server.

```bash
$ rsync -avzP elastos-node-20220610-linux-x86_64-alpha.tgz* target-server:
```

Remote **login** to the target server.

```bash
$ ssh target
```

Now we are on the target server. **Verify** the checksum.

```bash
target$ shasum -c elastos-node-20220610-linux-x86_64-alpha.tgz.digest
elastos-node-20220610-linux-x86_64-alpha.tgz: OK
```

**Unpack** the tarball.

```bash
target$ tar xf elastos-node-20220610-linux-x86_64-alpha.tgz
```

**Check** the return code

```bash
target$ echo $?
0
```

**Run** the script and check how to use.

```bash
target$ ~/node/node.sh
```

For a more detailed setup and usage, please refer to the related docs.
