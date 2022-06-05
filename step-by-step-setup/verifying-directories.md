# Verifying Directories

Installing **tree** utility to list contents of directories in a tree-like format.

```bash
$ sudo apt-get install -y tree
[ ... many outputs ... ]
```

Currently, if all things work well, we have the following directory.

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
├── carrier                         # carrier bootstrap folder
│   ├── bootstrapd.conf             # config file
│   ├── ela-bootstrapd              # daemon program
│   └── var                         # running data (*)
│
├── did                             # did folder
│   ├── config.json                 # config file
│   ├── did                         # daemon program
│   └── elastos_did                 # chain data and log (*)
│
├── eid                             # eid folder
│   ├── data                        # running data and logs (*)
│   ├── eid                         # daemon and client program
│   └── logs                        # log files (*)
│
├── eid-oracle                      # eid-oracle folder
│   └── *.js
│
├── ela                             # ela folder
│   ├── config.json                 # config file
│   ├── ela                         # daemon program
│   ├── ela-cli                     # client program, to send commands to ela chain
│   ├── elastos                     # chain data and log (*)
│   └── keystore.dat                # keystore file, the wallet
│
├── esc                             # esc folder
│   ├── data                        # running data and logs (*)
│   ├── esc                         # daemon and client program
│   └── logs                        # log files (*)
│
├── esc-oracle                      # esc-oracle folder
│   └── *.js
│
├── extern
│   └── node-v14.17.0-linux-x64     # nodejs required by esc-oracle and eid-oracle
│
└── node.sh                         # the operating script
```

Please some directories marked with asterisks are running data and logs files, which will be generated during the program running.\
