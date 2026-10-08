#!/usr/bin/env bash
# pick.sh open          (action) open the picker popup for the focused pane
# pick.sh               (popup)  fzf over every space, tab and pane; type "herdr:<name>(<id>) " into
#                                the pane the picker was opened from, without submitting it, or
#                                go to the item instead
# pick.sh preview <id> <pane>  (fzf)  the last screenful of a pane (a space's or tab's focused one)
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
  p=${3:-${2:-}}
  case "$p" in *:p*) ;; *) exit 0 ;; esac
  max=${FZF_PREVIEW_LINES:-40}
  # The last lines of a pane that fit: the blank rows under its last output are dropped first.
  screen() { # pane lines
    "$H" pane read "$1" --source visible --ansi 2>/dev/null | awk -v max="$2" '
      { line[NR] = $0; t = $0; gsub(/\033\[[0-9;?]*[A-Za-z]/, "", t); if (t ~ /[^[:space:]]/) last = NR }
      END { for (i = (last > max ? last - max + 1 : 1); i <= last; i++) print line[i] }'
  }
  if [ "$p" = "${2:-}" ]; then screen "$p" "$max"; exit 0; fi
  # A space or tab shows every pane of its (active) tab, each under its id and name with its last
  # lines: one pane's full screen would be cut by the preview and hide the others.
  panes=$("$H" pane list | jq -r --arg p "$p" '(.result.panes | map(select(.pane_id == $p))[0].tab_id) as $t
    | .result.panes[] | select(.tab_id == $t) | "\(.pane_id)\t\(.agent // .label // "shell" | gsub("[\t\n\r]"; " "))"')
  n=$(grep -c . <<<"$panes")
  each=$(( (max - n) / (n > 0 ? n : 1) ))
  [ "$each" -ge 1 ] || each=1
  while IFS=$'\t' read -r id name; do
    printf '\033[2m── %s  %s\033[0m\n' "$id" "$name"
    screen "$id" "$each"
  done <<<"$panes"
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

# One line per item in tree order: id, name, the line shown (colored id, dimmed ancestors), the
# pane the preview shows (a space's or tab's focused pane), and its kind for `herdr <kind> <id>`:
# agent, pane, tab or workspace.
# A tab with one pane is listed once, as its pane: its own row would read the same. A pane whose
# name the tab title already carries (auto-titled tabs) adds just its agent, if any, instead of
# repeating the name; in a tab of several panes it adds its name then, to tell it from the tab. What Enter types keeps names
# short: Herdr titles agent panes and tabs after the conversation ("2 · develop › claude › ..."),
# long and changing, so an agent's pane goes by its agent and a tab by its first title part.
# Tabs and newlines in names would break the row, so they become spaces.
rows=$("$H" api snapshot | jq -r '
  def clean: gsub("[\t\n\r]"; " ");
  def id($i): "\u001b[36m\(($i + "       ")[0:7])\u001b[0m ";
  def dim($s): "\u001b[2m\($s)\u001b[0m";
  (.result.snapshot // .result) as $s
  | ([$s.layouts[]? | {key: .tab_id, value: .focused_pane_id}] | from_entries) as $fp
  | $s.workspaces[] as $w
  | ($w.label | clean) as $wl
  | [$w.workspace_id, $wl, id($w.workspace_id) + "\u001b[1m\($wl)\u001b[0m", $fp[$w.active_tab_id // ""] // "", "workspace"],
    ($s.tabs[] | select(.workspace_id == $w.workspace_id) as $t | ($t.label | clean) as $tl
      | ([$s.panes[] | select(.tab_id == $t.tab_id)] | length) as $np
      | (if $np > 1 then [$t.tab_id, ($tl | sub("^[0-9]+ · "; "") | split(" › ")[0]), id($t.tab_id) + dim("\($wl) / ") + $tl, $fp[$t.tab_id] // "", "tab"] else empty end),
        ($s.panes[] | select(.tab_id == $t.tab_id) | (.label // .agent // "shell" | clean) as $n
          | (if ($tl | contains($n)) then (if $np > 1 then .agent // $n else .agent end) else $n end) as $leaf
          | [.pane_id, (.agent // $n | clean), id(.pane_id) + dim("\($wl) / ") + if $leaf then dim("\($tl) / ") + $leaf else $tl end, .pane_id,
             (if .agent then "agent" else "pane" end)]))
  | join("\t")') || exit 1

# Start on the pane the picker was opened from.
start=$(awk -F'\t' -v t="$target" '$1 == t { print NR; exit }' <<<"$rows")
# Under a CJK locale fzf counts ambiguous-width glyphs (· › │ ─ ○) as two columns, while herdr's
# terminal draws them as one, so rows and the preview misalign and leave stale cells behind.
export RUNEWIDTH_EASTASIAN="${RUNEWIDTH_EASTASIAN:-0}"
# Look-and-feel defaults go through FZF_DEFAULT_OPTS so fzf_opts from pick.conf can override them.
# The preview drops below the list only when a right-side preview would be under 50 columns.
# Tab marks several items to type at once; ctrl-o (or alt-enter) goes to the item instead. Terminals
# send ctrl-enter as plain enter, so it cannot be told apart.
out=$(FZF_DEFAULT_OPTS="--layout=reverse --no-hscroll --prompt='herdr> ' --preview-window='right,55%,border-left,<50(down,50%,border-top)' \
--header='enter: insert · tab: several · ctrl-o: go to · ctrl-/: preview' \
--bind='ctrl-/:change-preview-window(right,80%,border-left|down,80%,border-top|right,55%,border-left)' $(conf fzf_opts)" \
  fzf <<<"$rows" --ansi --delimiter='\t' --with-nth=3 --sync --bind "start:pos(${start:-1}),change:first" \
  --multi --expect=ctrl-o,alt-enter --preview "bash $(printf %q "$self") preview {1} {4}") || exit 0
key=$(head -n1 <<<"$out")
sel=$(tail -n +2 <<<"$out")
[ -n "$sel" ] || exit 0

# Go to a pane, tab or space. Herdr's CLI focuses an agent's pane but no other pane; the socket's
# pane.focus does, so without nc the jump stops at the pane's tab.
go() { # id
  case "$1" in
  (*:p*)
    "$H" agent focus "$1" >/dev/null 2>&1 && return
    [ -n "${HERDR_SOCKET_PATH:-}" ] && command -v nc >/dev/null &&
      printf '{"id":"ids","method":"pane.focus","params":{"pane_id":"%s"}}\n' "$1" |
      nc -U -w 1 "$HERDR_SOCKET_PATH" 2>/dev/null | grep -q '"result"' && return
    "$H" tab focus "$("$H" pane get "$1" | jq -r .result.pane.tab_id)" >/dev/null ;;
  (*:t*) "$H" tab focus "$1" >/dev/null ;;
  (*) "$H" workspace focus "$1" >/dev/null ;;
  esac
}
if [ -n "$key" ]; then
  go "$(head -n1 <<<"$sel" | cut -f1)"
  exit 0
fi

# Written for the agent that reads it: the Herdr CLI's own nouns and the ID its commands take
# (`herdr agent read wD:p3`), the name only as a hint. A bare `devin` would read as a target, and
# agent commands refuse agent kinds.
tpl=$(conf template)
[ -n "$tpl" ] || tpl='herdr {kind} {id} ({name})'
# Each pick in one pass, so a name that contains "{id}" stays as it is; several are comma-separated.
text=$(cut -f1,2,5 <<<"$sel" | jq -Rrn --arg t "$tpl" '[inputs | split("\t") as [$id, $name, $kind]
  | $t | gsub("\\{(?<k>name|id|kind)\\}"; if .k == "name" then $name elif .k == "id" then $id else $kind end)
  | sub(" \\(\\)$"; "")] | join(", ")') || exit 1
"$H" pane send-text "$target" "$text " >/dev/null
