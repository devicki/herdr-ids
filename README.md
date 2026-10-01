# herdr-ids

English | [한국어](README.ko.md)

![herdr-ids: ids in the sidebar, and picking a pane to hand to an agent](docs/demo.svg)

Show [Herdr](https://herdr.dev) pane and workspace ids (`w9:p1`, `w9`) in the sidebar, and pick any space, tab or pane to type its id into your agent: "check the tests in herdr:dev-server(w1:p2)".

Herdr has no built-in sidebar token for ids. This plugin reports them as custom metadata tokens, `$pane_id` on every pane and `$workspace_id` on every workspace, and keeps them current.

## Requirements

- Herdr 0.9.1 or newer, on Linux or macOS. Windows is not supported; run Herdr in WSL there.
- `bash` (3.2, the macOS default, is enough) and `jq` 1.6 or newer
- [`fzf`](https://github.com/junegunn/fzf) 0.36 or newer for the picker. Ubuntu 22.04 ships 0.29, which is too old; get a newer one from Homebrew or the fzf releases.

## Setup

The examples below start from Herdr's default configuration. Herdr's config file is `~/.config/herdr/config.toml`.

### 1. Install

Run this on every machine or account whose panes you want labeled:

```sh
herdr plugin install devicki/herdr-ids --ref v0.3.5
```

`--ref` pins a release. Leave it out to track `main` instead. Releases are listed under [tags](https://github.com/devicki/herdr-ids/tags).

The plugin writes the ids when the Herdr server starts. If the server is already running, write them once now:

```sh
herdr plugin action invoke devicki.ids.sync
```

### 2. Show the ids in the sidebar

The tokens stay invisible until your sidebar rows use them. These are Herdr's default rows with the two tokens added:

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

If you already customized `rows`, add `"$pane_id"` or `{ token = "$pane_id", dim = true }` to whichever row you like instead.

When you attach to remote machines from a laptop, the laptop draws the sidebar, so this goes in the laptop's config. The plugin itself runs on each remote machine (step 1).

### 3. Bind the picker to a key

`prefix+i` is free in Herdr's default keymap (the prefix is `ctrl+b` unless you changed it):

```toml
[[keys.command]]
key = "prefix+i"
type = "plugin_action"
command = "devicki.ids.pick"
description = "pick a herdr target"
```

When you work on a remote machine, add this to that machine's config.

### 4. Reload

```sh
herdr server reload-config
```

Restart Herdr if the sidebar does not pick up the change.

## Picking a target

Press the key in the pane you are typing into, for example an agent's prompt:

- Type to fuzzy-search the id and the `space / tab / pane` path. The cursor starts on your own pane.
- The right side previews the highlighted pane's screen.
- Enter types `herdr:dev-server(w1:p2) ` into your pane without submitting it, so you can finish the sentence. Esc cancels.

When a pane's name is already part of its tab's title, as with auto-titled tabs or a tab named after its only pane, the line adds only the pane's agent, if it has one, instead of repeating the name. The picker lists the Herdr server it runs on, so with several machines you see the current machine's panes.

## Settings

Customize the picker in `$(herdr plugin config-dir devicki.ids)/pick.conf`, one `key = value` per line; ` #` after a value starts a note. The plugin creates the file with every key commented out the first time it runs. Every key is optional:

```
# what Enter types; {name} and {id} are filled in
template = herdr:{name}({id})
# popup size, in cells or as a percentage
width = 90%
height = 70%
# any fzf options; they override the picker's own look (layout, prompt, preview window, colors)
fzf_opts = --border=rounded --color=hl:#7aa2f7 --preview-window=down,40%
```

By default the popup is 90% wide and 70% tall, and the preview takes the right 55%. The preview moves below the list when the right side would be narrower than 50 columns. Use `--preview-window=hidden` in `fzf_opts` to turn it off.

## Update and uninstall

Herdr has no update command; reinstall at the new tag. `pick.conf` and the enabled state survive a reinstall, and `herdr plugin list` shows the installed version.

```sh
herdr plugin install devicki/herdr-ids --ref v0.3.5 --yes
herdr plugin uninstall devicki.ids
```

## How it works

Tokens are runtime metadata, so the startup hook writes them for every pane and workspace. The `pane.created`, `pane.moved` and `workspace.created` hooks resync them, since a move to another workspace changes the pane id. Run `ids: resync tokens` (`devicki.ids.sync`) if anything looks stale.

## Troubleshooting

- **No ids in the sidebar**: check that step 2 went into the config of the Herdr that draws your sidebar, and run `herdr plugin action invoke devicki.ids.sync` on the machine whose panes are missing them.
- **Garbled rows under a Korean, Japanese or Chinese locale**: fzf counts ambiguous-width glyphs such as `·`, `›` and `│` as two columns in these locales, while Herdr draws them as one. The picker sets `RUNEWIDTH_EASTASIAN=0` for fzf to match. If your setup really draws them two columns wide, set `RUNEWIDTH_EASTASIAN=1` in the Herdr server's environment.
- **The picker does not open**: the reason Herdr gives goes to a toast (turn toasts on with `[ui.toast] delivery`) and to `herdr plugin log list --plugin devicki.ids`.

## Development

```sh
herdr plugin link .
./test.sh   # throwaway named session: startup, new pane, cross-workspace move, restart
```

To release, bump `version` in `herdr-plugin.toml`, update the `--ref` in both READMEs, commit, then `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`.

`docs/demo/record.sh` re-records `docs/demo.svg` in an isolated Herdr with made-up workspaces (needs `tmux`).

## License

MIT
