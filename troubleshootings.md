---
description: '[this page needs further fix and editing]'
---

# Troubleshootings

### How to restore node synchronization?

The node cannot be started normally or is highly out of sync due to factors such as the server

1. Check if the node version is up to date
2. Check if memory and hard disk are sufficient
3. There may be data errors, you need to shut down the node and delete the data to resynchronize. Here is an example of deploying the script path rule

*   ELA

    ```bash
    $ ~/node/node.sh ela stop
    $ rm -r ~/node/ela/elastos/data
    $ ~/node/node.sh ela start
    ```
*   DID

    ```bash
    $ ~/node/node.sh did stop
    $ rm -r ~/node/did/elastos_did/data
    $ ~/node/node.sh did start
    ```
*   ESC

    ```bash
    $ ~/node/node.sh esc stop
    $ rm -r ~/node/esc/data/geth
    $ rm -r ~/node/esc/data/header
    $ rm -r ~/node/esc/data/spv_transaction_info.db
    $ rm -r ~/node/esc/data/store
    $ ~/node/node.sh esc start
    ```
*   EID

    ```bash
    $ ~/node/node.sh eid stop
    $ rm -r ~/node/eid/data/geth
    $ rm -r ~/node/eid/data/header
    $ rm -r ~/node/eid/data/spv_transaction_info.db
    $ rm -r ~/node/eid/data/store
    $ ~/node/node.sh eid start
    ```
*   Arbiter

    ```bash
    $ ~/node/node.sh arbiter stop
    $ rm -r ~/node/arbiter/elastos_arbiter/data
    $ ~/node/node.sh arbiter start
    ```



    ### The script complains: cannot find jq

    jq is required to parse JSON config files. Install it by running the following commands:

    ```bash
    $ sudo apt-get update -y
    $ sudo apt-get install -y jq
    ```
