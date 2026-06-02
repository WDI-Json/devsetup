#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$REPO_DIR/dotfiles"
VSCODE_SRC="$REPO_DIR/vscode"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
LOG="$REPO_DIR/log.txt"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if $DRY_RUN; then
  printf '\e[1;33m=== DRY RUN — no changes will be made ===\e[0m\n\n'
  LOG="/dev/null"
else
  echo "Bootstrap log — $(date)" > "$LOG"
  echo "" >> "$LOG"
fi

log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ok()   { $DRY_RUN || echo "[OK]     $*" >> "$LOG"; }
dry()  { printf '  \e[90mwould: %s\e[0m\n' "$*"; }
fail() {
  printf '\e[1;31m[FAILED]\e[0m %s\n' "$*"
  $DRY_RUN || echo "[FAILED] $*" >> "$LOG"
}

backup_and_link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "${dst}.backup"
    log "Backed up $(basename "$dst")"
  fi
  ln -sf "$src" "$dst"
}

# ── Xcode Command Line Tools ──────────────────────────────────────────────────
log "Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
  ok "Xcode Command Line Tools (already installed)"
elif $DRY_RUN; then
  dry "install Xcode Command Line Tools"
else
  xcode-select --install
  read -rp "Press Enter once the Xcode CLT installation is complete..."
  if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools"
  else
    fail "Xcode Command Line Tools"
  fi
fi

# ── Homebrew ──────────────────────────────────────────────────────────────────
log "Checking Homebrew..."
if command -v brew &>/dev/null; then
  ok "Homebrew (already installed)"
elif $DRY_RUN; then
  dry "install Homebrew"
else
  if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew"
  else
    fail "Homebrew — cannot continue without it"
    exit 1
  fi
fi

# ── Brewfile ──────────────────────────────────────────────────────────────────
log "Checking Brewfile packages..."
if $DRY_RUN; then
  missing=$(brew bundle check --file="$DOTFILES/Brewfile" 2>&1 | grep "is not installed" || true)
  if [[ -n "$missing" ]]; then
    echo "  Packages not yet installed:"
    while IFS= read -r line; do
      dry "$line"
    done <<< "$missing"
  else
    echo "  All packages already installed"
  fi
else
  brew_success=false
  for attempt in 1 2 3; do
    if brew bundle --file="$DOTFILES/Brewfile"; then
      brew_success=true
      break
    fi
    log "brew bundle attempt $attempt failed (likely network) — retrying in 10s..."
    sleep 10
  done

  if $brew_success; then
    ok "All Homebrew packages"
  else
    echo "" >> "$LOG"
    echo "=== Homebrew packages still missing after 3 attempts ===" >> "$LOG"
    missing=$(brew bundle check --file="$DOTFILES/Brewfile" 2>&1 | grep "is not installed" || true)
    if [[ -n "$missing" ]]; then
      while IFS= read -r line; do
        fail "brew: $line"
      done <<< "$missing"
    else
      fail "brew bundle (unknown error — run 'brew bundle' manually)"
    fi
    echo "" >> "$LOG"
  fi
fi

# ── Fonts ─────────────────────────────────────────────────────────────────────
log "CascadiaMono fonts..."
if $DRY_RUN; then
  dry "copy CascadiaMono/*.ttf to ~/Library/Fonts/"
elif cp "$REPO_DIR/CascadiaMono/"*.ttf "$HOME/Library/Fonts/" 2>/dev/null; then
  ok "CascadiaMono fonts"
else
  fail "CascadiaMono fonts (copy failed)"
fi

# ── SSH key ───────────────────────────────────────────────────────────────────
log "Checking SSH key..."
if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
  ok "SSH key (already exists)"
elif $DRY_RUN; then
  dry "generate SSH key ~/.ssh/id_ed25519 (ed25519)"
else
  if ssh-keygen -t ed25519 -C "Wouter.Dijks@topicus.nl" -f "$HOME/.ssh/id_ed25519" -N ""; then
    ok "SSH key generated"
    log "Add this SSH key to GitHub: https://github.com/settings/keys"
    cat "$HOME/.ssh/id_ed25519.pub"
    # Loop until GitHub recognises the key (or user aborts with Ctrl-C)
    while true; do
      read -rp "Press Enter once the key is added to GitHub to verify..."
      if ssh -T -o StrictHostKeyChecking=accept-new -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
        ok "SSH key verified with GitHub"
        break
      fi
      log "GitHub did not accept the key yet — add it at https://github.com/settings/keys and try again."
    done
  else
    fail "SSH key generation"
  fi
fi

# ── Dotfile symlinks ──────────────────────────────────────────────────────────
log "Dotfile symlinks..."
if $DRY_RUN; then
  dry "link ~/.zshrc -> $DOTFILES/.zshrc"
elif backup_and_link "$DOTFILES/.zshrc" "$HOME/.zshrc"; then
  ok "Symlink ~/.zshrc"
else
  fail "Symlink ~/.zshrc"
fi

# ── Neovim config symlink ─────────────────────────────────────────────────────
log "Neovim config..."
if $DRY_RUN; then
  dry "link ~/.config/nvim -> $REPO_DIR/neovim"
else
  mkdir -p "$HOME/.config"
  if backup_and_link "$REPO_DIR/neovim" "$HOME/.config/nvim"; then
    ok "Symlink ~/.config/nvim"
  else
    fail "Symlink ~/.config/nvim"
  fi
fi

# ── Git commit-msg hook ───────────────────────────────────────────────────────
log "Git commit-msg hook..."
if $DRY_RUN; then
  dry "install .git/hooks/commit-msg -> $REPO_DIR/hooks/commit-msg"
else
  if ln -sf "../../hooks/commit-msg" "$REPO_DIR/.git/hooks/commit-msg"; then
    ok "Git commit-msg hook installed"
  else
    fail "Git commit-msg hook"
  fi
fi

# ── Ghostty config symlink ────────────────────────────────────────────────────
GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
log "Ghostty config..."
if $DRY_RUN; then
  dry "link Ghostty config -> $REPO_DIR/ghostty/config"
else
  mkdir -p "$GHOSTTY_DIR"
  if backup_and_link "$REPO_DIR/ghostty/config" "$GHOSTTY_DIR/config"; then
    ok "Symlink Ghostty config"
  else
    fail "Symlink Ghostty config"
  fi
fi

# ── VS Code symlinks ──────────────────────────────────────────────────────────
log "VS Code config symlinks..."
if $DRY_RUN; then
  dry "link VS Code settings.json   -> $VSCODE_SRC/settings.json"
  dry "link VS Code keybindings.json -> $VSCODE_SRC/keybindings.json"
else
  mkdir -p "$VSCODE_USER"
  for file in settings.json keybindings.json; do
    if backup_and_link "$VSCODE_SRC/$file" "$VSCODE_USER/$file"; then
      ok "Symlink VS Code $file"
    else
      fail "Symlink VS Code $file"
    fi
  done
fi

# ── VS Code extensions ────────────────────────────────────────────────────────
log "VS Code extensions..."
if command -v code &>/dev/null || $DRY_RUN; then
  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" == \#* ]] && continue
    if $DRY_RUN; then
      dry "install extension: $ext"
    else
      printf "  %-50s" "$ext"
      if code --install-extension "$ext" --force &>/dev/null; then
        printf "ok\n"
        ok "VS Code extension: $ext"
      else
        printf "FAILED\n"
        fail "VS Code extension: $ext"
      fi
    fi
  done < "$VSCODE_SRC/extensions.txt"
else
  fail "VS Code CLI (code command not found — extensions skipped)"
fi

# ── macOS settings ────────────────────────────────────────────────────────────
log "macOS settings..."
if $DRY_RUN; then
  dry "run scripts/macos.sh (defaults write for Dock, Finder, keyboard, etc.)"
elif bash "$REPO_DIR/scripts/macos.sh" &>/dev/null; then
  ok "macOS settings"
else
  fail "macOS settings (check scripts/macos.sh)"
fi

# ── Dock ──────────────────────────────────────────────────────────────────────
log "Dock..."
if $DRY_RUN; then
  dry "run scripts/dock.sh (configure Dock via dockutil)"
elif command -v dockutil &>/dev/null; then
  if bash "$REPO_DIR/scripts/dock.sh"; then
    ok "Dock"
  else
    fail "Dock (check scripts/dock.sh)"
  fi
else
  fail "Dock (dockutil not found — was brew bundle successful?)"
fi

# ── Repos ─────────────────────────────────────────────────────────────────────
log "Repositories..."
if $DRY_RUN; then
  bash "$REPO_DIR/scripts/repos.sh" --dry-run
elif bash "$REPO_DIR/scripts/repos.sh"; then
  ok "Repositories"
else
  fail "Repositories (check scripts/repos.sh and SSH key)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  printf '\e[1;33mDry run complete — run without --dry-run to apply.\e[0m\n'
else
  echo "" >> "$LOG"
  failure_count=$(grep -c "^\[FAILED\]" "$LOG" 2>/dev/null || echo 0)
  if [[ "$failure_count" -gt 0 ]]; then
    printf '\e[1;31m%s failure(s) — see log.txt\e[0m\n' "$failure_count"
    grep "^\[FAILED\]" "$LOG"
  else
    printf '\e[1;32mAll steps completed successfully\e[0m\n'
  fi
  echo ""
  log "Bootstrap complete. Open a new terminal to apply shell changes."
  log "Some macOS settings require a logout or restart."
fi
