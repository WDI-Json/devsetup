#!/usr/bin/env bash
set -euo pipefail

dockutil --remove all --no-restart

apps=(
  "/Applications/Ghostty.app"
  "/Applications/Google Chrome.app"
  "/Applications/Visual Studio Code.app"
  "/Applications/Obsidian.app"
  "/Applications/Claude.app"
)

for app in "${apps[@]}"; do
  if [[ -d "$app" ]]; then
    echo "Adding: $app"
    dockutil --add "$app" --no-restart
  else
    echo "Skipping (not found): $app"
  fi
done

killall Dock
echo "Dock configured."
