# Installing Programs

The init command will download the prebuilt binary package, extract and place the executables in the right place, and write the config files required.

Using the **init** command without specifing chain program name will process the following programs (chains) in one go.

* Elastos Carrier Bootstrap
* Elastos ELA Mainchain
* Elastos DID Sidechain
* Elastos ESC Sidechain (with ESC Oracle)
* Elastos EID Sidechain (with EID Oracle)
* Elastos Arbiter

```
$ ~/node/node.sh init
```

As an alternative, you can also run the init command one by one.
