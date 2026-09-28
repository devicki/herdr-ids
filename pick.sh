#!/usr/bin/env bash
# pick.sh open   (action) open the picker popup for the focused pane
# pick.sh        (popup)  fzf over every space, tab and pane; type "herdr:<name>(<id>) " into
#                         the pane the picker was opened from, without submitting it
set -uo pipefail

# herdr runs plugin commands with a minimal PATH; ensure jq and fzf resolve on common installs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

H="${HERDR_BIN_PATH:-herdr}"

if [ "${1:-}" = open ]; then
  target=$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | jq -r '.focused_pane_id // empty' 2>/dev/null)
  target="${target:-${HERDR_PANE_ID:-}}"
  [ -n "$target" ] || { echo "ids: no focused pane to type into" >&2; exit 1; }
  exec "$H" plugin pane open --plugin "${HERDR_PLUGIN_ID:-devicki.ids}" --entrypoint picker \
    --placement popup --env IDS_TARGET="$target" >/dev/null
fi

target="${IDS_TARGET:?run through the ids: pick action}"
command -v fzf >/dev/null || { echo "ids: fzf is not installed" >&2; read -r -n1; exit 1; }

# One line per item in tree order: id, name, and the "id  path" line shown to the user.
rows=$("$H" api snapshot | jq -r '(.result.snapshot // .result) as $s
  | $s.workspaces[] as $w
  | [$w.workspace_id, $w.label, "\($w.workspace_id)  \($w.label)"],
    ($s.tabs[] | select(.workspace_id == $w.workspace_id) as $t
      | [$t.tab_id, $t.label, "\($t.tab_id)  \($w.label) / \($t.label)"],
        ($s.panes[] | select(.tab_id == $t.tab_id) | (.label // .agent // "shell") as $n
          | [.pane_id, $n, "\(.pane_id)  \($w.label) / \($t.label) / \($n)"]))
  | @tsv') || exit 1

# Start on the pane the picker was opened from.
start=$(awk -F'\t' -v t="$target" '$1 == t { print NR; exit }' <<<"$rows")
pick=$(fzf <<<"$rows" --delimiter='\t' --with-nth=3 --layout=reverse --prompt='herdr> ' \
  --header='type to search · enter: insert · esc: cancel' --bind "load:pos(${start:-1})") || exit 0

IFS=$'\t' read -r id name _ <<<"$pick"
text="herdr:{name}({id})"
[ ! -f "${HERDR_PLUGIN_CONFIG_DIR:-}/template" ] || text=$(head -n1 "$HERDR_PLUGIN_CONFIG_DIR/template")
text=${text//\{name\}/$name}
text=${text//\{id\}/$id}
"$H" pane send-text "$target" "$text " >/dev/null
