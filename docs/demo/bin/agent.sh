#!/usr/bin/env bash
# Stand-in agent for the demo recording: shows prior work, takes one request, and reads the
# pane id it was given with the real herdr CLI.
clear
printf '\e[1;38;5;173m✻ claude\e[0m \e[2m· shop-api\e[0m\n\n'
printf '\e[2m> add refresh-token rotation to the auth service\e[0m\n\n'
printf '\e[32m●\e[0m Updated src/auth/refresh.ts \e[2m(+42 -7)\e[0m\n'
printf '\e[32m●\e[0m Updated src/auth/session.ts \e[2m(+12 -3)\e[0m\n'
printf '\e[32m●\e[0m Rotation is in. The test watcher is running in another tab.\n\n'
IFS= read -r -e -p $'\e[1m❯\e[0m ' line
id=$(grep -o 'w[0-9A-Za-z]*:p[0-9A-Za-z]*' <<<"$line" | head -n1)
[ -n "$id" ] || exec sleep 100000
printf '\n\e[32m●\e[0m Reading %s\n' "$id"
sleep 0.8
herdr pane read "$id" --source recent --lines 12 | grep -E 'FAIL|●|Expected|Received' | sed 's/^/  \x1b[2m│\x1b[0m /'
sleep 1
printf '\n\e[32m●\e[0m Found it: the expiry check uses \e[1m<=\e[0m instead of \e[1m<\e[0m. Fixing src/auth/login.ts\n'
exec sleep 100000
