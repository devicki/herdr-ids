#!/usr/bin/env bash
# Stand-in dev server for the demo recording.
clear
printf '\n  \e[32;1mVITE\e[0m \e[32mv5.4.2\e[0m  ready in \e[1m312\e[0m ms\n\n'
printf '  \e[32m➜\e[0m  \e[1mLocal:\e[0m   \e[36mhttp://localhost:5173/\e[0m\n'
printf '  \e[2m➜  Network: use --host to expose\e[0m\n\n'
while :; do
  sleep 6
  printf '\e[2m%s\e[0m \e[36m[vite]\e[0m hmr update \e[2m/src/components/Header.tsx\e[0m\n' "$(date +%H:%M:%S)"
done
