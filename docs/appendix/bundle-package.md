# Tarball Setup

Users who prefer an all-in-one bundle package can check this page.

Download the tarball package.

```bash
$ wget -c https://download.elastos.io/elastos-node/elastos-node-20220612-linux-x86_64-alpha.tgz
```

Download the SHA checksums.

```bash
$ wget https://download.elastos.io/elastos-node/elastos-node-20220612-linux-x86_64-alpha.tgz.digest
```

Check SHA checksums of the package.

```bash
$ shasum -c elastos-node-20220612-linux-x86_64-alpha.tgz.digest
elastos-node-20220612-linux-x86_64-alpha.tgz: OK
```

Extract the package.

```bash
$ tar xf elastos-node-20220612-linux-x86_64-alpha.tgz
```

Check SHA checksums of the extracted files.

```bash
$ cd ~/node
$ shasum -c checksum.txt
```

The expected result follows.

```bash
./arbiter/arbiter: OK
./carrier/ela-bootstrapd: OK
./did/did: OK
./eid-oracle/checkillegalevidence.js: OK
./eid-oracle/common.js: OK
./eid-oracle/crosschain_eid.js: OK
./eid-oracle/ctrt.js: OK
./eid-oracle/getblklogs.js: OK
./eid-oracle/getblknum.js: OK
./eid-oracle/getexisttxs.js: OK
./eid-oracle/getillegalevidencebyheight.js: OK
./eid-oracle/gettxinfo.js: OK
./eid-oracle/sendrechargetransaction.js: OK
./eid/eid: OK
./ela/ela: OK
./ela/ela-cli: OK
./esc-oracle/checkillegalevidence.js: OK
./esc-oracle/common.js: OK
./esc-oracle/crosschain_oracle.js: OK
./esc-oracle/ctrt.js: OK
./esc-oracle/faileddeposittransactions.js: OK
./esc-oracle/frozen_account.js: OK
./esc-oracle/getblklogs.js: OK
./esc-oracle/getblknum.js: OK
./esc-oracle/getexisttxs.js: OK
./esc-oracle/getfaileddeposittransactionbyhash.js: OK
./esc-oracle/getillegalevidencebyheight.js: OK
./esc-oracle/gettxinfo.js: OK
./esc-oracle/processedinvalidwithdrawtx.js: OK
./esc-oracle/receivedInvaliedwithrawtx.js: OK
./esc-oracle/sendrechargetransaction.js: OK
./esc-oracle/smallcrosschaintransaction.js: OK
./esc/esc: OK
./node.sh: OK
```

The you can use `node.sh` to do the next operations.
