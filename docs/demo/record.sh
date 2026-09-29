#!/usr/bin/env bash
# Re-record docs/demo.svg: an isolated Herdr (its own HOME, only this plugin linked), a made-up
# project with stand-in agents, and a scripted pick. Needs tmux, jq, git and python3.
# The screen is captured from tmux, which renders Herdr faithfully, and render.py turns the
# frames into SVG. DEMO_WORK picks the scratch dir (default: a new mktemp dir).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${DEMO_WORK:-$(mktemp -d)}
herdr=$(command -v herdr)
# Unix socket paths must stay under 108 bytes, so HOME is a short symlink to the scratch dir.
home="${XDG_RUNTIME_DIR:-/tmp}/herdr-ids-demo"
tmx=(tmux -L herdr-ids-demo -f /dev/null)

mkdir -p "$work/home/.config/herdr" "$work/projects"
ln -sfn "$work/home" "$home"
cp "$here/config.toml" "$work/home/.config/herdr/config.toml"
cp "$here/bashrc" "$work/home/.bashrc"
for p in shop-api:fix/login-expiry shop-web:feat/header-nav; do
  dir="$work/projects/${p%%:*}"
  mkdir -p "$dir" && git -C "$dir" init -q -b main
  git -C "$dir" -c user.name=demo -c user.email=demo@example.com commit -q --allow-empty -m init
  git -C "$dir" checkout -q -b "${p#*:}"
done

env_=(env -i HOME="$home" PATH="$here/bin:${herdr%/*}:/usr/local/bin:/usr/bin:/bin" TERM=xterm-256color
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 SHELL=/bin/bash USER=demo LOGNAME=demo)
h() { "${env_[@]}" "$herdr" "$@"; }
cleanup() {
  "${tmx[@]}" kill-server 2>/dev/null || :
  h server stop >/dev/null 2>&1 || :
  rm -f "$home"
}
trap cleanup EXIT

h plugin link "$repo" >/dev/null
"${env_[@]}" "$herdr" server >/dev/null 2>&1 &
for _ in $(seq 50); do h pane list >/dev/null 2>&1 && break; sleep 0.2; done

# The scene: shop-api with an agent tab and a failing test watcher, shop-web with a busy agent
# beside a dev server.
api="$work/projects/shop-api"
web="$work/projects/shop-web"
h workspace create --cwd "$api" >/dev/null # w1, w1:t1, w1:p1
h tab rename w1:t1 agent >/dev/null
h tab create --workspace w1 --cwd "$api" --label tests >/dev/null # w1:t2, w1:p2
h workspace create --cwd "$web" >/dev/null # w2, w2:t1, w2:p1
h tab rename w2:t1 agent >/dev/null
h pane split w2:p1 --direction right --ratio 0.55 --no-focus >/dev/null # w2:p2
h pane rename w1:p1 "refresh tokens" >/dev/null
h pane rename w1:p2 tests >/dev/null
h pane rename w2:p1 "header nav" >/dev/null
h pane rename w2:p2 dev-server >/dev/null
h pane run w1:p1 'exec agent.sh' >/dev/null
h pane run w1:p2 'exec tests.sh' >/dev/null
h pane run w2:p1 'exec worker.sh' >/dev/null
h pane run w2:p2 'exec dev.sh' >/dev/null
h pane report-agent w1:p1 --source demo --agent claude --state idle >/dev/null
h pane report-agent w2:p1 --source demo --agent codex --state working >/dev/null
h plugin action invoke devicki.ids.sync >/dev/null
h workspace focus w1 >/dev/null
h tab focus w1:t1 >/dev/null
sleep 1

keys() { "${tmx[@]}" send-keys -t demo "$@"; }
type_() { local s=$1 i; for ((i = 0; i < ${#s}; i++)); do keys -l "${s:i:1}"; sleep "${2:-0.05}"; done; }

"${tmx[@]}" new-session -d -s demo -x 132 -y 32 "$(printf '%q ' "${env_[@]}") $herdr"
"${tmx[@]}" set -g status off
"${tmx[@]}" set -g escape-time 0
sleep 1.5
# Snapshot the screen every 50ms; render.py drops the unchanged ones.
while :; do
  printf '@@frame %s\n' "$(($(date +%s%N) / 1000000))"
  "${tmx[@]}" capture-pane -t demo -p -e -N
  sleep 0.05
done >"$work/frames.log" &
capture=$!
sleep 3.5                                     # the sidebar: w1, w2, claude · w1:p1, codex · w2:p1
type_ "The login test is failing. Check "
sleep 0.6
keys C-b; sleep 0.25; keys i; sleep 2         # the picker opens on this pane
type_ tests 0.14; sleep 1
keys Down; sleep 2.5                          # preview: the failing test
keys Enter; sleep 1                           # herdr:tests(w1:p2) lands in the prompt
type_ "and fix it."; sleep 0.8
keys Enter; sleep 5                           # the agent reads w1:p2 through the herdr CLI
kill "$capture"
wait "$capture" 2>/dev/null || :

python3 "$here/render.py" "$work/frames.log" "$repo/docs/demo.svg" 132 32
echo "wrote $repo/docs/demo.svg ($(du -h "$repo/docs/demo.svg" | cut -f1))"
