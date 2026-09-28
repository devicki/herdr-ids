# herdr-ids

Show [Herdr](https://herdr.dev) pane and workspace ids (`w9:p1`, `w9`) in the sidebar, and pick any space, tab or pane to type its id into your agent ("check the tests in herdr:dev-server(w1:p2)").

Herdr has no built-in sidebar token for ids. This plugin reports them as custom metadata tokens, `$pane_id` on every pane and `$workspace_id` on every workspace, and keeps them current.

## Install

```sh
herdr plugin install devicki/herdr-ids
```

Requires `bash` and `jq` (plus `fzf` for the picker). Install it on every machine or account whose panes you want labeled.

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

## Pick a target and type it

`ids: pick a target and type it` opens a popup with every space, tab and pane:

```
herdr> dev                                   │ $ npm run dev
> w1:p2   api / 1 · shell / dev-server       │ server listening on :3000
  w2:t1   web / dev                          │ $
```

Type to fuzzy-search the id and the `space / tab / pane` path. The right side previews the highlighted pane's screen. When a pane's name is already part of its tab's title, as with auto-titled tabs, the pane shows its agent instead so the line does not repeat itself. Enter types `herdr:dev-server(w1:p2) ` into the pane you opened the picker from, without submitting it, so you can finish telling your agent what to do there. Esc cancels. The cursor starts on your own pane. This needs [`fzf`](https://github.com/junegunn/fzf).

Bind it to a key in `config.toml`:

```toml
[[keys.command]]
key = "prefix+i"
type = "plugin_action"
command = "devicki.ids.pick"
description = "pick a herdr target"
```

Customize it in `$(herdr plugin config-dir devicki.ids)/pick.conf`, one `key = value` per line. Every key is optional:

```
# what Enter types; {name} and {id} are filled in
template = herdr:{name}({id})
# popup size, in cells or as a percentage
width = 90%
height = 70%
# any fzf options; they override the picker's own look (layout, prompt, preview window, colors)
fzf_opts = --border=rounded --color=hl:#7aa2f7 --preview-window=down,40%
```

By default the popup is 90% wide and 70% tall, and the preview takes the right 55% (it moves below the list when the right side would be narrower than 50 columns). Use `--preview-window=hidden` in `fzf_opts` to turn the preview off.

## How it works

Tokens are runtime metadata, so the startup hook writes them for every pane and workspace. The `pane.created`, `pane.moved` and `workspace.created` hooks resync them, since a move to another workspace changes the pane id. Run `ids: resync tokens` if anything looks stale.

## Development

```sh
herdr plugin link .
./test.sh   # throwaway named session: startup, new pane, cross-workspace move, restart
```

## License

MIT
