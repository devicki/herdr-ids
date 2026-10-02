#!/usr/bin/env bash
# End-to-end check on a throwaway named session: tokens after startup, the pick action, the picker
# itself (several picks, going to a pane), a new pane, a cross-workspace move, a new tab, and a
# server restart. Needs the plugin linked first (herdr plugin link .), tmux and fzf.
set -euo pipefail
unset HERDR_SOCKET_PATH HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID
export HERDR_SESSION=ids-test

up() {
  herdr server >/dev/null 2>&1 &
  for _ in $(seq 50); do herdr pane list >/dev/null 2>&1 && return; sleep 0.2; done
  echo "FAIL: server did not start" >&2
  exit 1
}
here=$(cd "$(dirname "$0")" && pwd)
tmx=(tmux -L ids-test -f /dev/null)
cleanup() {
  "${tmx[@]}" kill-server 2>/dev/null || :
  herdr server stop >/dev/null 2>&1 || :
  sleep 0.5
  herdr session delete "$HERDR_SESSION" >/dev/null 2>&1 || :
}
# Every pane and workspace must carry its own id as a token, and every pane its tab's id.
check() {
  sleep 1.5
  bad=$(herdr pane list | jq -r '.result.panes[] | select(.tokens.pane_id != .pane_id or .tokens.tab_id != .tab_id) | .pane_id')
  bad="$bad$(herdr workspace list | jq -r '.result.workspaces[] | select(.tokens.workspace_id != .workspace_id) | .workspace_id')"
  [ -z "$bad" ] || { echo "FAIL ($1): wrong or missing token on $bad" >&2; exit 1; }
}
cleanup
trap cleanup EXIT

up
p1=$(herdr workspace create --cwd "$PWD" | jq -r .result.root_pane.pane_id)
check "startup + workspace.created"
HERDR_PANE_ID=$p1 bash "$here/pick.sh" open ||
  { echo "FAIL: the pick action did not open the picker cleanly" >&2; exit 1; }

# The picker in a terminal: tab picks two items and enter types both into the target pane; ctrl-o
# goes to a pane without an agent in another space instead.
sock=$(herdr session list | awk -v s="$HERDR_SESSION" '$1 == s { print $4 }')
picker() {
  "${tmx[@]}" new-session -d -x 160 -y 40 "env HERDR_SESSION=$HERDR_SESSION IDS_TARGET=$p1 HERDR_SOCKET_PATH=$sock bash $(printf %q "$here/pick.sh")"
  sleep 1.5
}
herdr pane split "$p1" --direction right --no-focus >/dev/null
other=$(herdr workspace create --cwd "$PWD" --no-focus | jq -r .result.root_pane.pane_id)
herdr workspace focus "${p1%%:*}" >/dev/null
picker
"${tmx[@]}" send-keys Tab Tab Enter
sleep 1
n=$(herdr pane read "$p1" --source visible | grep -o -E 'herdr (agent|pane|tab|workspace) [^ ,]+' | wc -l)
[ "$n" -eq 2 ] || { echo "FAIL: picking two items typed $n reference(s)" >&2; exit 1; }
picker
"${tmx[@]}" send-keys -l "^$other"
sleep 0.5
"${tmx[@]}" send-keys C-o
sleep 1
focused=$(herdr api snapshot | jq -r '(.result.snapshot // .result).focused_pane_id')
[ "$focused" = "$other" ] || { echo "FAIL: ctrl-o on $other left the focus on $focused" >&2; exit 1; }
"${tmx[@]}" kill-server 2>/dev/null || :
p2=$(herdr pane split "$p1" --direction right --no-focus | jq -r .result.pane.pane_id)
check "pane.created"
herdr pane move "$p2" --new-workspace --no-focus >/dev/null
check "pane.moved"
herdr tab create --workspace "${p1%%:*}" --no-focus >/dev/null
check "new tab"
herdr server stop >/dev/null
sleep 1
up
check "restart"
echo PASS
