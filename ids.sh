#!/usr/bin/env bash
# Report every pane's and workspace's public id as a sidebar token: $pane_id, $workspace_id.
set -uo pipefail

# herdr runs plugin commands with a minimal PATH; ensure jq resolves on common installs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

H="${HERDR_BIN_PATH:-herdr}"
src="devicki.ids"

"$H" pane list | jq -r '.result.panes[].pane_id' | while IFS= read -r p; do
  "$H" pane report-metadata "$p" --source "$src" --token pane_id="$p" >/dev/null
done
"$H" workspace list | jq -r '.result.workspaces[].workspace_id' | while IFS= read -r w; do
  "$H" workspace report-metadata "$w" --source "$src" --token workspace_id="$w" >/dev/null
done
