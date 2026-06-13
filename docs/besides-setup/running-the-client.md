# Running the Client

To interact with a chain daemon, `node.sh` provides a per-chain `client` command, a wrapper around the chain's CLI utility (for example `ela-cli`). It supplies the RPC username and password from the chain's config automatically, so you do not have to pass them by hand.

```bash
~/node/node.sh ela client info getcurrentheight
1178878
```

The JSON-RPC API is more complete than the CLI client. The equivalent call is `jsonrpc` (the alias `rpc` also works). The request JSON must be surrounded with single quotes.

```bash
~/node/node.sh ela jsonrpc '{"method":"getblockcount"}'
{
  "jsonrpc": "2.0",
  "result": 1178878,
  "id": null,
  "error": null
}
```

`client` and `rpc` are available for every chain, for example:

```bash
~/node/node.sh esc rpc '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

The EVM side chains (`esc`, `eid`, `pg`) bind their RPC and WebSocket endpoints to `127.0.0.1`, so these calls work from the node itself but not from the network. See [SECURITY.md](../../SECURITY.md) for the security model and how to reach RPC remotely.
