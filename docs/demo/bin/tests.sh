#!/usr/bin/env bash
# Stand-in test watcher for the demo recording.
clear
printf '\e[42;30;1m PASS \e[0m src/auth/refresh.test.ts\n'
printf '\e[42;30;1m PASS \e[0m src/auth/session.test.ts\n'
printf '\e[41;37;1m FAIL \e[0m src/auth/login.test.ts\n'
printf '  \e[31;1m● login › rejects an expired token\e[0m\n\n'
printf '    expect(received).toBe(expected)\n\n'
printf '    Expected: \e[32m401\e[0m\n'
printf '    Received: \e[31m200\e[0m\n\n'
printf '\e[1mTests:\e[0m \e[31;1m1 failed\e[0m, \e[32;1m23 passed\e[0m, 24 total\n'
printf '\e[2mWatching for file changes...\e[0m\n'
exec sleep 100000
