# Running node.sh

When running node.sh for the first time, it is required to select a network manually.

```bash
$ ~/node/node.sh
```

Both Mainnet and testnet are currently supported. Press Enter to select the default mainnet. To set the testnet, you can enter two and press Enter.

```bash
Please select the network:

  1. MainNet
  2. TestNet

? Your option: [1] ENTER
INFO: config file: $HOME/.config/elastos/node.json
```

We will rerun the script without any arguments, which should display the usage.

```bash
$ ~/node/node.sh
```

If the output is similar to the following, the installation should work.

{% code fullWidth="false" %}
```bash
Usage: node.sh [CHAIN] COMMAND [OPTIONS]
Manage Elastos Node

Diag Info:

  Deploy Path:    /home/ubuntu/node
  Script SHA1:    94b9870
  Chains Type:    mainnet

Available Chains:

  ela             N/A
  esc             N/A
  esc-oracle      N/A
  eid             N/A
  eid-oracle      N/A
  arbiter         N/A
  carrier         N/A

Available Commands:

  start           Start chain daemon
  stop            Stop chain daemon
  status          Print chain daemon status
  client          Run chain client
  jsonrpc         Call JSON-RPC API
  update          Install or update chain
  init            Install and configure chain
  register_bpos   Register ELA BPoS
  activate_bpos   Activate ELA BPoS
  unregister_bpos Unregister ELA BPoS
  vote_bpos       Vote ELA BPoS
  stake_bpos      Stake ELA BPoS
  unstake_bpos    Unstake ELA BPoS
  claim_bpos      Claim rewards ELA BPoS
  register_crc    Register ELA CRC
  activate_crc    Activate ELA CRC
  unregister_crc  Unregister ELA CRC
  send            Send crypto
  transfer        Send crypto crosschain
  compress_log    Compress log files to save disk space
  remove_log      Remove log files
```
{% endcode %}

The first argument specifies the chain (program) name. The second one specifies the action to perform. The N/A means a chain has not been installed. Please be notified that the CHAIN argument is optional. If it is absent, all chains will be issued COMMAND.

To prevent prefixing the script path every run, use set\_path.

```bash
$ ~/node.sh set_path
```

This will auto-edit the profile file. Please note a re-login is required to make the PATH effective.

```
Updating /Path/To/Home/.bash_profile...
INFO: please re-login to make PATH effective
```
