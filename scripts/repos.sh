#!/usr/bin/env bash
set -uo pipefail

GITHUB_DIR="$HOME/GITHUB"
GITHUB_USER="WDI-Json"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

clone_or_update() {
  local repo="$1"
  local dir="$GITHUB_DIR/$repo"
  if $DRY_RUN; then
    if [[ -d "$dir/.git" ]]; then
      printf '  \e[90mwould: git pull --ff-only  %s\e[0m\n' "$dir"
    else
      printf '  \e[90mwould: git clone git@github.com:%s/%s.git -> %s\e[0m\n' "$GITHUB_USER" "$repo" "$dir"
    fi
    return
  fi
  if [[ -d "$dir/.git" ]]; then
    echo "Updating $repo..."
    git -C "$dir" pull --ff-only
  else
    echo "Cloning $repo..."
    git clone "git@github.com:$GITHUB_USER/$repo.git" "$dir"
  fi
}

mkdir -p "$GITHUB_DIR"

clone_or_update "neovim_config"
