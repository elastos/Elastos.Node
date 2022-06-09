# Build from the Source Code

## Summary

Generally, software build gives you confidence that you have the right and precise mapping between your code and your desired product. It will take 5 to 10 minutes in the [cloud build service](https://travis-ci.com/github/elastos/Elastos.ELA.Supernode/builds).

## System requirements

* **RAM**: 2 GB
* **HDD**: 8 GB
* **OS**: Ubuntu 16.04 x86\_64

## Building steps

```bash
$ cd $HOME
$ git clone https://github.com/elastos/Elastos.ELA.Supernode
$ cd $HOME/Elastos.ELA.Supernode/build
$ ./build.sh
```

## Build result

The generated package contains all the programs and the automatic script to run a supernode. Copy (rsync) it to the target server, and extract it to the $HOME folder.

**List** the build results.

```bash
$ ls -1 ~/Elastos.ELA.Supernode/release/Linux-x86_64
20210602-182454
```

Dive into the build result **folder**.

```bash
$ cd ~/Elastos.ELA.Supernode/release/Linux-x86_64/20210602-182454
```

**Transfer** the tarball to the target server.

```bash
$ rsync -avzP elastos-supernode-20210602-Linux-x86_64-alpha.tgz.* target-server:
```

Remote **login** to the target server.

```bash
$ ssh target-server
```

Now we are on the target server. **Verify** the checksum.

```bash
user@target-server $ shasum -c elastos-supernode-20210602-Linux-x86_64-alpha.tgz.digest
elastos-supernode-20210602-Linux-x86_64-alpha.tgz: OK
```

**Unpack** the tarball.

```bash
user@target-server $ tar xf elastos-supernode-20210602-Linux-x86_64-alpha.tgz
```

**Check** the return code

```bash
user@target-server $ echo $?
0
```

**Run** the script.

```bash
user@target-server $ ~/node/node.sh
```

For a more detailed setup and usage, please refer to [Elastos Supernode Guide](../step-by-step-setup.md).
