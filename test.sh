#!/usr/bin/env bash
# End-to-end check on a throwaway named session: tokens after startup, the pick action, a new
# pane, a cross-workspace move, a new tab, and a server restart. Needs the plugin linked first: herdr plugin link .
set -euo pipefail
unset HERDR_SOCKET_PATH HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID
export HERDR_SESSION=ids-test

up() {
  herdr server >/dev/null 2>&1 &
  for _ in $(seq 50); do herdr pane list >/dev/null 2>&1 && return; sleep 0.2; done
  echo "FAIL: server did not start" >&2
  exit 1
}
cleanup() {
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
HERDR_PANE_ID=$p1 bash "$(dirname "$0")/pick.sh" open ||
  { echo "FAIL: the pick action did not open the picker cleanly" >&2; exit 1; }
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
