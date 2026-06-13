# Verifying Directories

Installing the **tree** utility to list the contents of directories in a tree-like format.

```bash
$ sudo apt-get install -y tree
[ ... many outputs ... ]
```

The exact set of directories depends on the active profile. A `full`-profile node, once initialized, has the layout below. A `mainchain`-profile node has only `ela` and `node.sh`.

```bash
$ tree -L 2 ~/node
~/node                              # root
├── arbiter                         # arbiter folder
│   ├── arbiter                     # arbiter program
│   ├── config.json                 # arbiter config file
│   ├── ela-cli -> ../ela/ela-cli   # link to ela client program
│   ├── elastos_arbiter             # running data and logs (*)
│   └── keystore.dat                # keystore file, copied from ela
│
├── eid                             # eid (Identity Chain) folder
│   ├── data                        # running data, keystore, logs (*)
│   ├── eid                         # daemon and client program
│   └── logs                        # log files (*)
│
├── eid-oracle                      # eid-oracle folder
│   └── *.js
│
├── ela                             # ela (main chain) folder
│   ├── config.json                 # config file
│   ├── ela                         # daemon program
│   ├── ela-cli                     # client program, to send commands to ela chain
│   ├── elastos                     # chain data and log (*)
│   └── keystore.dat                # keystore file, the wallet
│
├── esc                             # esc (Smart Chain) folder
│   ├── data                        # running data, keystore, logs (*)
│   ├── esc                         # daemon and client program
│   └── logs                        # log files (*)
│
├── esc-oracle                      # esc-oracle folder
│   └── *.js
│
├── pg                              # pg (PGA Chain) folder
│   ├── data                        # running data, keystore, logs (*)
│   ├── pg                          # daemon and client program
│   └── logs                        # log files (*)
│
├── pg-oracle                       # pg-oracle folder
│   └── *.js
│
├── extern
│   └── node-v23.10.0-linux-x64     # nodejs required by the oracle services
│
└── node.sh                         # the operating script
```

The directories marked with an asterisk hold running data and log files, which are generated while the programs run.

For each EVM side chain (`esc`, `eid`, `pg`), the `data` directory also holds the chain's keystore (`data/keystore/`) and, on a mining node, the cold reward address recorded in `data/miner_address.txt`.

The decommissioned ECO and PGP side chains are not part of any profile and are not created by this script. A leftover `eco`/`eco-oracle` directory from an older install can be removed with `node.sh eco purge`.
