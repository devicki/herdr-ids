#!/usr/bin/env bash
# pick.sh open          (action) open the picker popup for the focused pane
# pick.sh               (popup)  fzf over every space, tab and pane; type "herdr:<name>(<id>) " into
#                                the pane the picker was opened from, without submitting it
# pick.sh preview <id>  (fzf)    the last screenful of a pane
set -uo pipefail

# herdr runs plugin commands with a minimal PATH; ensure jq and fzf resolve on common installs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

H="${HERDR_BIN_PATH:-herdr}"

# Settings live in $HERDR_PLUGIN_CONFIG_DIR/pick.conf, one `key = value` per line; ` #` starts a
# note, so `#` inside a value (fzf colors) is kept.
conf() {
  local f="${HERDR_PLUGIN_CONFIG_DIR:-}/pick.conf"
  [ -f "$f" ] && sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$f" |
    sed -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//' | tail -n1
}

case "${1:-}" in
open)
  target=$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | jq -r '.focused_pane_id // empty' 2>/dev/null)
  target="${target:-${HERDR_PANE_ID:-}}"
  [ -n "$target" ] || { echo "ids: no focused pane to type into" >&2; exit 1; }
  set -- --placement popup
  w=$(conf width) && [ -n "$w" ] && set -- "$@" --width "$w"
  h=$(conf height) && [ -n "$h" ] && set -- "$@" --height "$h"
  # An action has nowhere to print, so a popup Herdr refuses (another one open, say) is a toast.
  err=$("$H" plugin pane open --plugin "${HERDR_PLUGIN_ID:-devicki.ids}" --entrypoint picker \
    "$@" --env IDS_TARGET="$target" 2>&1 >/dev/null) || {
    msg=$(jq -r '.error.message // empty' <<<"$err" 2>/dev/null)
    "$H" notification show "ids: the picker did not open" --body "${msg:-$err}" >/dev/null 2>&1
    echo "ids: ${msg:-$err}" >&2
    exit 1
  }
  exit 0
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
# The start event and the pos/first actions arrived in fzf 0.36; older ones exit on the options.
v=$(fzf --version | awk '{print $1}')
awk -v v="$v" 'BEGIN { split(v, n, "."); exit !(n[1] > 0 || n[2] >= 36) }' ||
  { echo "ids: the picker needs fzf 0.36 or newer (found $v)" >&2; read -r -n1; exit 1; }
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# One line per item in tree order: id, name, and the line shown (colored id, dimmed ancestors).
# A pane whose name the tab title already carries (auto-titled tabs, a tab named after its only
# pane) adds just its agent, if any, instead of repeating the name. What Enter types names an
# agent's pane by its agent: Herdr labels it with the conversation title, which is long and changes.
# Tabs and newlines in names would break the row, so they become spaces.
rows=$("$H" api snapshot | jq -r '
  def clean: gsub("[\t\n\r]"; " ");
  def id($i): "\u001b[36m\(($i + "       ")[0:7])\u001b[0m ";
  def dim($s): "\u001b[2m\($s)\u001b[0m";
  (.result.snapshot // .result) as $s
  | $s.workspaces[] as $w
  | ($w.label | clean) as $wl
  | [$w.workspace_id, $wl, id($w.workspace_id) + "\u001b[1m\($wl)\u001b[0m"],
    ($s.tabs[] | select(.workspace_id == $w.workspace_id) as $t | ($t.label | clean) as $tl
      | [$t.tab_id, $tl, id($t.tab_id) + dim("\($wl) / ") + $tl],
        ($s.panes[] | select(.tab_id == $t.tab_id) | (.label // .agent // "shell" | clean) as $n
          | (if ($tl | contains($n)) then .agent else $n end) as $leaf
          | [.pane_id, (.agent // $n | clean), id(.pane_id) + dim("\($wl) / ") + if $leaf then dim("\($tl) / ") + $leaf else $tl end]))
  | join("\t")') || exit 1

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
tpl=$(conf template)
# In one pass, so a name that contains "{id}" stays as it is.
[ -n "$tpl" ] || tpl='herdr:{name}({id})'
text=$(jq -rn --arg t "$tpl" --arg name "$name" --arg id "$id" \
  '$t | gsub("\\{(?<k>name|id)\\}"; if .k == "name" then $name else $id end)') || exit 1
"$H" pane send-text "$target" "$text " >/dev/null
