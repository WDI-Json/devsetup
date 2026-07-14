#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$REPO_DIR/dotfiles"
VSCODE_SRC="$REPO_DIR/vscode"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
LOG="$REPO_DIR/log.txt"
WINGET_FILE="$DOTFILES/Wingetfile"
OS_TYPE=""

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [[ "${OS:-}" == "Windows_NT" ]]; then
  OS_TYPE="windows"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  OS_TYPE="macos"
else
  OS_TYPE="unsupported"
fi

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

install_winget_pkg() {
  local pkg="$1"
  if winget list --id "$pkg" --exact --accept-source-agreements &>/dev/null; then
    ok "winget package already installed: $pkg"
    return 0
  fi
  if winget install --id "$pkg" --exact --accept-source-agreements --accept-package-agreements &>/dev/null; then
    ok "winget package installed: $pkg"
    return 0
  fi
  fail "winget package install failed: $pkg"
  return 1
}

bootstrap_windows() {
  log "Detected Windows — using winget-based bootstrap"
  if ! command -v winget &>/dev/null; then
    fail "winget not found. Install App Installer from Microsoft Store and re-run."
    exit 1
  fi
  ok "winget available"

  log "Installing winget packages from dotfiles/Wingetfile..."
  if [[ ! -f "$WINGET_FILE" ]]; then
    fail "Missing $WINGET_FILE"
  elif $DRY_RUN; then
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      dry "winget install --id $pkg --exact --accept-source-agreements --accept-package-agreements"
    done < "$WINGET_FILE"
  else
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      install_winget_pkg "$pkg"
    done < "$WINGET_FILE"
  fi

  log "Windows Subsystem for Linux (WSL) + Ubuntu..."
  if $DRY_RUN; then
    dry "wsl --install --no-distribution"
    dry "winget install --id Canonical.Ubuntu --exact --accept-source-agreements --accept-package-agreements"
    dry "wsl --install -d Ubuntu"
  elif command -v wsl.exe &>/dev/null; then
    if wsl.exe -l -q 2>/dev/null | tr -d '\r' | grep -iq '^Ubuntu'; then
      ok "Ubuntu already present in WSL"
    else
      wsl_enabled=false
      if wsl.exe --status &>/dev/null || wsl.exe --install --no-distribution &>/dev/null; then
        wsl_enabled=true
        ok "WSL installed/enabled"
      fi
      if ! $wsl_enabled; then
        fail "Unable to enable WSL (run elevated PowerShell and re-run bootstrap)"
      fi

      ubuntu_installed=false
      for ubuntu_pkg in "Canonical.Ubuntu" "Canonical.Ubuntu.2404"; do
        if winget list --id "$ubuntu_pkg" --exact --accept-source-agreements &>/dev/null \
          || winget install --id "$ubuntu_pkg" --exact --accept-source-agreements --accept-package-agreements &>/dev/null; then
          ubuntu_installed=true
          ok "Ubuntu package installed via winget ($ubuntu_pkg)"
          break
        fi
      done
      if ! $ubuntu_installed; then
        fail "Ubuntu package install via winget failed"
      fi

      if wsl.exe --install -d Ubuntu &>/dev/null || wsl.exe -l -q 2>/dev/null | tr -d '\r' | grep -iq '^Ubuntu'; then
        ok "Ubuntu registered in WSL"
      else
        fail "Ubuntu registration in WSL failed (restart may be required, then run: wsl --install -d Ubuntu)"
      fi
    fi
  else
    fail "wsl.exe not found on PATH"
  fi

  echo ""
  if ! $DRY_RUN; then
    failure_count=$(grep -c "^\[FAILED\]" "$LOG" 2>/dev/null || true)
    failure_count="${failure_count:-0}"
    if [[ "$failure_count" -gt 0 ]]; then
      printf '\e[1;31m%s failure(s) — see log.txt\e[0m\n' "$failure_count"
      grep "^\[FAILED\]" "$LOG"
    else
      printf '\e[1;32mWindows bootstrap completed successfully\e[0m\n'
    fi
  else
    printf '\e[1;33mDry run complete — run without --dry-run to apply.\e[0m\n'
  fi
  exit 0
}

backup_and_link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "${dst}.backup"
    log "Backed up $(basename "$dst")"
  fi
  ln -sf "$src" "$dst"
}

# ── OS-specific routing ─────────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "windows" ]]; then
  bootstrap_windows
elif [[ "$OS_TYPE" == "unsupported" ]]; then
  fail "Unsupported OS. This bootstrap currently supports macOS and Windows."
  exit 1
fi

# ── Interactive prompts ───────────────────────────────────────────────────────
if ! $DRY_RUN; then
  printf '\e[1;36m==>\e[0m Setup — answer a few questions or press Enter for defaults\n'
  read -rp "  SSH key email/comment (leave blank for none): " SSH_EMAIL
  read -rp "  Change hostname? [y/N]: " change_hostname
  if [[ "$change_hostname" =~ ^[Yy] ]]; then
    read -rp "  New hostname: " MAC_HOSTNAME
    export MAC_HOSTNAME
  fi
  echo ""
fi

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

# ── oh-my-posh — trust binary (macOS Gatekeeper) ─────────────────────────────
log "Trusting oh-my-posh binary..."
if $DRY_RUN; then
  dry "xattr -dr com.apple.quarantine \$(brew --prefix)/bin/oh-my-posh"
elif command -v oh-my-posh &>/dev/null; then
  xattr -dr com.apple.quarantine "$(brew --prefix)/bin/oh-my-posh" 2>/dev/null && ok "oh-my-posh trusted" || ok "oh-my-posh (no quarantine attribute)"
else
  fail "oh-my-posh not found — was brew bundle successful?"
fi

# ── Ollama — pull models ──────────────────────────────────────────────────────
log "Pulling Ollama models..."
if $DRY_RUN; then
  dry "ollama pull qwen3:8b"
  dry "ollama pull nomic-embed-text"
elif command -v ollama &>/dev/null; then
  _ollama_was_running=false
  if pgrep -x ollama &>/dev/null; then
    _ollama_was_running=true
  else
    ollama serve &>/dev/null &
    _ollama_pid=$!
    sleep 3
  fi
  for _model in qwen3:8b nomic-embed-text; do
    if ollama pull "$_model"; then
      ok "Ollama $_model"
    else
      fail "ollama pull $_model"
    fi
  done
  if ! $_ollama_was_running && [[ -n "${_ollama_pid:-}" ]]; then
    kill "$_ollama_pid" 2>/dev/null || true
  fi
else
  fail "ollama not found — was brew bundle successful?"
fi

# ── Rancher Desktop — docker on PATH ─────────────────────────────────────────
log "Checking docker on PATH (Rancher Desktop)..."
if command -v docker &>/dev/null; then
  ok "docker is on PATH (Rancher Desktop driver available)"
elif $DRY_RUN; then
  dry "verify docker is on PATH — open Rancher Desktop and enable dockerd (moby) in Preferences → Container Engine"
else
  fail "docker not on PATH — open Rancher Desktop, enable dockerd (moby) in Preferences → Container Engine, then re-run"
fi

# ── minikube default driver ───────────────────────────────────────────────────
log "Checking minikube default driver..."
if $DRY_RUN; then
  dry "set minikube default driver to docker (minikube config set driver docker)"
elif ! command -v minikube &>/dev/null; then
  fail "minikube not found — was brew bundle successful?"
else
  current_driver=$(minikube config get driver 2>/dev/null || true)
  if [[ "$current_driver" == "docker" ]]; then
    ok "minikube default driver already set to docker (Rancher Desktop)"
  elif minikube config set driver docker 2>/dev/null; then
    ok "minikube default driver set to docker (Rancher Desktop)"
  else
    fail "minikube config set driver docker"
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
  if ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""; then
    ok "SSH key generated"
    # Ensure ssh-agent picks up the new key (macOS Keychain)
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null \
      || ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true

    log "Add this SSH key to GitHub: https://github.com/settings/keys"
    cat "$HOME/.ssh/id_ed25519.pub"
    while true; do
      read -rp "Press Enter once the key is added to GitHub to verify (or Ctrl-C to skip)... "
      ssh_output=$(ssh -T -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes \
                       -i "$HOME/.ssh/id_ed25519" git@github.com 2>&1)
      if echo "$ssh_output" | grep -q "successfully authenticated"; then
        ok "SSH key verified with GitHub"
        break
      fi
      echo ""
      log "GitHub response was:"
      echo "$ssh_output" | sed 's/^/    /'
      log "Verify the key at https://github.com/settings/keys and try again."
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

# ── mise config + tool install ────────────────────────────────────────────────
MISE_DIR="$HOME/.config/mise"
log "mise config..."
if $DRY_RUN; then
  dry "link ~/.config/mise/config.toml -> $REPO_DIR/mise/config.toml"
  dry "run 'mise install' to fetch Python, Node, Java"
else
  mkdir -p "$MISE_DIR"
  if backup_and_link "$REPO_DIR/mise/config.toml" "$MISE_DIR/config.toml"; then
    ok "Symlink mise config"
  else
    fail "Symlink mise config"
  fi
  if command -v mise &>/dev/null; then
    log "Installing tools listed in mise/config.toml (Python, Node, Java)..."
    if mise install --yes; then
      ok "mise tools installed"
      log "Installed runtimes:"
      mise current | sed 's/^/  /' | tee -a "$LOG"
    else
      fail "mise install (run 'mise install' manually to retry)"
    fi
  else
    fail "mise (command not found — was brew bundle successful?)"
  fi
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

# ── CAPSLOCK → Escape (hidutil LaunchAgent) ───────────────────────────────────
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
CAPSLOCK_PLIST="com.local.capslock-to-escape.plist"
log "CAPSLOCK → Escape..."
if $DRY_RUN; then
  dry "link $LAUNCH_AGENTS_DIR/$CAPSLOCK_PLIST -> $DOTFILES/$CAPSLOCK_PLIST"
  dry "launchctl load $LAUNCH_AGENTS_DIR/$CAPSLOCK_PLIST"
else
  mkdir -p "$LAUNCH_AGENTS_DIR"
  if backup_and_link "$DOTFILES/$CAPSLOCK_PLIST" "$LAUNCH_AGENTS_DIR/$CAPSLOCK_PLIST"; then
    ok "Symlink $CAPSLOCK_PLIST"
    launchctl load "$LAUNCH_AGENTS_DIR/$CAPSLOCK_PLIST" 2>/dev/null \
      && ok "LaunchAgent loaded (CAPSLOCK → Escape active)" \
      || ok "LaunchAgent registered (active on next login)"
  else
    fail "Symlink $CAPSLOCK_PLIST"
  fi
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

# ── WDI-Notes vault symlink (iCloud + Obsidian) ───────────────────────────────
# wdi-notes lives in the iCloud-synced Obsidian vault (single source of truth) and
# is git-tracked there (remote: github.com/WDI-Json/wdi-notes). Link ~/GITHUB/wdi-notes
# -> the vault so the familiar path works and pushes go to GitHub from one copy.
# On a fresh machine iCloud may not be signed in / synced yet, so the vault won't
# exist — in that case skip cleanly and link it later (re-run bootstrap once synced).
WDI_NOTES_LINK="$HOME/GITHUB/wdi-notes"
WDI_NOTES_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/WDI-Notes"
log "WDI-Notes vault symlink..."
if $DRY_RUN; then
  if [[ -d "$WDI_NOTES_VAULT" ]]; then
    dry "link $WDI_NOTES_LINK -> $WDI_NOTES_VAULT"
  else
    dry "skip — iCloud vault not present yet; link after iCloud syncs"
  fi
elif [[ ! -d "$WDI_NOTES_VAULT" ]]; then
  log "iCloud vault not found — sign in to iCloud, let Obsidian/iCloud sync, then re-run bootstrap (or link manually)"
  ok "WDI-Notes vault symlink (skipped — iCloud not synced yet)"
elif [[ -L "$WDI_NOTES_LINK" ]]; then
  ok "WDI-Notes vault symlink (already linked)"
elif [[ -e "$WDI_NOTES_LINK" ]]; then
  fail "WDI-Notes: $WDI_NOTES_LINK exists and is not a symlink — remove that clone, then re-run (the vault is the source of truth)"
else
  mkdir -p "$HOME/GITHUB"
  if ln -s "$WDI_NOTES_VAULT" "$WDI_NOTES_LINK"; then
    ok "WDI-Notes vault symlink"
  else
    fail "WDI-Notes vault symlink"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  printf '\e[1;33mDry run complete — run without --dry-run to apply.\e[0m\n'
else
  echo "" >> "$LOG"
  failure_count=$(grep -c "^\[FAILED\]" "$LOG" 2>/dev/null || true)
  failure_count="${failure_count:-0}"
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
