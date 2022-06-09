---
description: WIP...
---

# Running the Client

To interact with the chain daemons, node.sh implements a client command, which is a wrapper to the ela-cli utility. You don't need to manually supply rpc username and password. when using node.sh, this will _the users' time._

TODO: Put one, two or three simple command lines to call node features.

Next:

Connect chain daemons by ela-cli

```bash
~/node/node.sh ela client info getcurrentheight
1178878
```

The JSON RPC API is more complete and powerful than the client version.

Check with this equivalent command. Please note the request JSON must be surrounded with '.

```bash
~/node/node.sh ela jsonrpc '{"method":"getblockcount"}'
{
  "jsonrpc": "2.0",
  "result": 1178878,
  "id": null,
  "error": null
}
```
