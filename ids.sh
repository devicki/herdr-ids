#!/usr/bin/env bash
# Report every pane's and workspace's public id as a sidebar token: $pane_id, $workspace_id. Herdr
# takes no metadata on tabs, so each pane also carries its tab's id as $tab_id.
set -uo pipefail

# herdr runs plugin commands with a minimal PATH; ensure jq resolves on common installs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

H="${HERDR_BIN_PATH:-herdr}"
src="devicki.ids"

# A commented pick.conf on first run, so the picker's settings have a file to edit.
conf="${HERDR_PLUGIN_CONFIG_DIR:-}/pick.conf"
if [ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" ] && [ ! -e "$conf" ] && mkdir -p "$HERDR_PLUGIN_CONFIG_DIR" 2>/dev/null; then
  cat 2>/dev/null >"$conf" <<'EOF' || :
# ids picker settings: one `key = value` per line, all optional. Lines starting with # are ignored,
# and ` #` after a value starts a note.
#
# What Enter types; {name} and {id} are filled in. Default: herdr:{name}({id})
# template = {id}
#
# Popup size, in cells or as a percentage. Default: 90% wide, 70% tall.
# width = 120
# height = 80%
#
# Any fzf options; they override the picker's own look (layout, prompt, preview window, colors).
# fzf_opts = --border=rounded --color=hl:#7aa2f7 --preview-window=down,40%
EOF
fi

"$H" pane list | jq -r '.result.panes[] | "\(.pane_id)\t\(.tab_id // "")"' | while IFS=$'\t' read -r p t; do
  "$H" pane report-metadata "$p" --source "$src" --token pane_id="$p" ${t:+--token tab_id="$t"} >/dev/null
done
"$H" workspace list | jq -r '.result.workspaces[].workspace_id' | while IFS= read -r w; do
  "$H" workspace report-metadata "$w" --source "$src" --token workspace_id="$w" >/dev/null
done
