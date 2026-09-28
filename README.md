# herdr-ids

Show [Herdr](https://herdr.dev) pane and workspace ids (`w9:p1`, `w9`) in the sidebar, so you can point an agent at another pane ("send this to w9:p2") without looking the id up.

Herdr has no built-in sidebar token for ids. This plugin reports them as custom metadata tokens, `$pane_id` on every pane and `$workspace_id` on every workspace, and keeps them current.

## Install

```sh
herdr plugin install devicki/herdr-ids
```

Requires `bash` and `jq`. Install it on every machine or account whose panes you want labeled.

## Show the ids

Add the tokens to your sidebar rows in `config.toml`. When you attach to remote machines, this goes in the config of the client that draws the sidebar, for example your laptop. Start from your current rows (defaults shown here) and put the tokens where you like:

```toml
[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  ["agent", { token = "$pane_id", dim = true }],
]

[ui.sidebar.spaces]
rows = [
  ["state_icon", "workspace", { token = "$workspace_id", dim = true }],
  ["branch", "git_status"],
]
```

Then run `herdr server reload-config` on that machine, or restart Herdr there if the sidebar does not pick it up.

## How it works

Tokens are runtime metadata, so the startup hook writes them for every pane and workspace. The `pane.created`, `pane.moved` and `workspace.created` hooks resync them, since a move to another workspace changes the pane id. Run `ids: resync tokens` if anything looks stale.

## Development

```sh
herdr plugin link .
./test.sh   # throwaway named session: startup, new pane, cross-workspace move, restart
```

## License

MIT
