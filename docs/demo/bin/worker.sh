#!/usr/bin/env bash
# Stand-in busy agent for the demo recording.
clear
printf '\e[1m>_ codex\e[0m \e[2m· shop-web\e[0m\n\n'
printf '\e[2m> move the header nav into its own component\e[0m\n\n'
for step in "Read src/components/Header.tsx" "Created src/components/HeaderNav.tsx" \
  "Updated src/components/Header.tsx" "Running npm run lint" "Updated src/styles/header.css"; do
  printf '\e[36m•\e[0m %s\n' "$step"
  sleep 4
done
exec sleep 100000
