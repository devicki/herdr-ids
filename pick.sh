#!/usr/bin/env bash
# pick.sh open          (action) open the picker popup for the focused pane
# pick.sh               (popup)  fzf over every space, tab and pane; type "herdr:<name>(<id>) " into
#                                the pane the picker was opened from, without submitting it
# pick.sh preview <id>  (fzf)    the last screenful of a pane
set -uo pipefail

# herdr runs plugin commands with a minimal PATH; ensure jq and fzf resolve on common installs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

H="${HERDR_BIN_PATH:-herdr}"

# Settings live in $HERDR_PLUGIN_CONFIG_DIR/pick.conf, one `key = value` per line.
conf() {
  local f="${HERDR_PLUGIN_CONFIG_DIR:-}/pick.conf"
  [ -f "$f" ] && sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$f" | tail -n1
}

case "${1:-}" in
open)
  target=$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | jq -r '.focused_pane_id // empty' 2>/dev/null)
  target="${target:-${HERDR_PANE_ID:-}}"
  [ -n "$target" ] || { echo "ids: no focused pane to type into" >&2; exit 1; }
  set -- --placement popup
  w=$(conf width) && [ -n "$w" ] && set -- "$@" --width "$w"
  h=$(conf height) && [ -n "$h" ] && set -- "$@" --height "$h"
  exec "$H" plugin pane open --plugin "${HERDR_PLUGIN_ID:-devicki.ids}" --entrypoint picker \
    "$@" --env IDS_TARGET="$target" >/dev/null
  ;;
preview)
  case "${2:-}" in *:p*) ;; *) exit 0 ;; esac
  # Drop the blank rows under the pane's last output, then keep what fits the preview.
  "$H" pane read "$2" --source visible --ansi 2>/dev/null | awk -v max="${FZF_PREVIEW_LINES:-40}" '
    { line[NR] = $0; t = $0; gsub(/\033\[[0-9;?]*[A-Za-z]/, "", t); if (t ~ /[^[:space:]]/) last = NR }
    END { for (i = (last > max ? last - max + 1 : 1); i <= last; i++) print line[i] }'
  exit 0
  ;;
esac

target="${IDS_TARGET:?run through the ids: pick action}"
command -v fzf >/dev/null || { echo "ids: fzf is not installed" >&2; read -r -n1; exit 1; }
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# One line per item in tree order: id, name, and the line shown (colored id, dimmed ancestors).
# A pane whose name the tab title already carries (auto-titled tabs, a tab named after its only
# pane) adds just its agent, if any, instead of repeating the name.
rows=$("$H" api snapshot | jq -r '
  def id($i): "\u001b[36m\(($i + "       ")[0:7])\u001b[0m ";
  def dim($s): "\u001b[2m\($s)\u001b[0m";
  (.result.snapshot // .result) as $s
  | $s.workspaces[] as $w
  | [$w.workspace_id, $w.label, id($w.workspace_id) + "\u001b[1m\($w.label)\u001b[0m"],
    ($s.tabs[] | select(.workspace_id == $w.workspace_id) as $t
      | [$t.tab_id, $t.label, id($t.tab_id) + dim("\($w.label) / ") + $t.label],
        ($s.panes[] | select(.tab_id == $t.tab_id) | (.label // .agent // "shell") as $n
          | (if ($t.label | contains($n)) then .agent else $n end) as $leaf
          | [.pane_id, $n, id(.pane_id) + dim("\($w.label) / ") + if $leaf then dim("\($t.label) / ") + $leaf else $t.label end]))
  | @tsv') || exit 1

# Start on the pane the picker was opened from.
start=$(awk -F'\t' -v t="$target" '$1 == t { print NR; exit }' <<<"$rows")
# Under a CJK locale fzf counts ambiguous-width glyphs (· › │ ─ ○) as two columns, while herdr's
# terminal draws them as one, so rows and the preview misalign and leave stale cells behind.
export RUNEWIDTH_EASTASIAN="${RUNEWIDTH_EASTASIAN:-0}"
# Look-and-feel defaults go through FZF_DEFAULT_OPTS so fzf_opts from pick.conf can override them.
# The preview drops below the list only when a right-side preview would be under 50 columns.
pick=$(FZF_DEFAULT_OPTS="--layout=reverse --no-hscroll --prompt='herdr> ' --preview-window='right,55%,border-left,<50(down,50%,border-top)' \
--header='type to search · enter: insert · esc: cancel' $(conf fzf_opts)" \
  fzf <<<"$rows" --ansi --delimiter='\t' --with-nth=3 --sync --bind "start:pos(${start:-1}),change:first" \
  --preview "bash $(printf %q "$self") preview {1}") || exit 0

IFS=$'\t' read -r id name _ <<<"$pick"
text=$(conf template)
[ -n "$text" ] || text='herdr:{name}({id})'
text=${text//\{name\}/$name}
text=${text//\{id\}/$id}
"$H" pane send-text "$target" "$text " >/dev/null
