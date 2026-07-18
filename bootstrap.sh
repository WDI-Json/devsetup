#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$REPO_DIR/dotfiles"
VSCODE_SRC="$REPO_DIR/vscode"
VSCODE_USER="" # Set after OS_TYPE is determined
LOG="$REPO_DIR/log.txt"
WINGET_FILE="$DOTFILES/Wingetfile"
OS_TYPE=""

# Variables for interactive setup (initialized to empty, may be set by prompts)
SSH_EMAIL=""
MAC_HOSTNAME=""

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
if [[ "${OS:-}" == "Windows_NT" ]]; then
  OS_TYPE="windows"
  WINGET="winget"
elif [[ "$UNAME_S" == MINGW* || "$UNAME_S" == MSYS* || "$UNAME_S" == CYGWIN* ]]; then
  OS_TYPE="windows"
  WINGET="winget"
elif [[ "$UNAME_S" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
  OS_TYPE="windows"
  WINGET="winget.exe"
elif [[ "$UNAME_S" == "Darwin" ]]; then
  OS_TYPE="macos"
  WINGET=""
else
  OS_TYPE="unsupported"
  WINGET=""
fi

# Set VS Code user config path based on OS
case "$OS_TYPE" in
  windows)
    VSCODE_USER="$APPDATA/Code/User"
    ;;
  macos)
    VSCODE_USER="$HOME/Library/Application Support/Code/User"
    ;;
  *)
    VSCODE_USER="$HOME/.config/Code/User"
    ;;
esac

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
  if $WINGET list --id "$pkg" --exact --accept-source-agreements &>/dev/null; then
    ok "winget package already installed: $pkg"
    return 0
  fi
  if $WINGET install --id "$pkg" --exact --accept-source-agreements --accept-package-agreements >/dev/null 2>>"$LOG"; then
    ok "winget package installed: $pkg"
    return 0
  fi
  fail "winget package install failed: $pkg"
  return 1
}

install_powershell_module() {
  local module="$1"
  if ! command -v powershell.exe &>/dev/null; then
    fail "PowerShell not found. Cannot install module: $module"
    return 1
  fi

  local check_cmd="if (Get-Module -ListAvailable -Name \"$module\") { exit 0 } else { exit 1 }"
  if powershell.exe -NoProfile -NonInteractive -Command "$check_cmd" &>/dev/null; then
    ok "PowerShell module already installed: $module"
    return 0
  fi

  local install_cmd="Install-Module -Name \"$module\" -Scope CurrentUser -Repository PSGallery -Force -AllowClobber"
  if powershell.exe -NoProfile -NonInteractive -Command "$install_cmd" >/dev/null 2>>"$LOG"; then
    ok "PowerShell module installed: $module"
    return 0
  fi

  fail "PowerShell module install failed: $module"
  return 1
}

wsl_has_ubuntu() {
  # wsl.exe -l outputs UTF-16LE; strip null bytes as well as carriage returns.
  wsl.exe -l -q 2>/dev/null | tr -d '\0\r' | grep -Eiq '^Ubuntu($|-)'
}

# Runs the WSL + Ubuntu installation. Intended to be called in a background
# subshell so it overlaps with the winget package installs. Stdout is captured
# by the caller and replayed after the wait.
_wsl_setup() {
  if ! command -v wsl.exe &>/dev/null; then
    fail "wsl.exe not found on PATH"
    return 1
  fi
  if wsl_has_ubuntu; then
    ok "Ubuntu already present in WSL"
    return 0
  fi

  local wsl_enabled=false
  if wsl.exe --status &>/dev/null; then
    wsl_enabled=true
    ok "WSL already enabled"
  elif wsl.exe --install --no-distribution >/dev/null 2>>"$LOG"; then
    wsl_enabled=true
    ok "WSL installed/enabled"
  fi
  if ! $wsl_enabled; then
    fail "Unable to enable WSL (run elevated PowerShell and re-run bootstrap)"
    return 1
  fi

  local ubuntu_installed=false
  # Try generic ID first, then explicit current LTS package ID as fallback.
  for ubuntu_pkg in "Canonical.Ubuntu" "Canonical.Ubuntu.2404"; do
    if $WINGET list --id "$ubuntu_pkg" --exact --accept-source-agreements &>/dev/null; then
      ubuntu_installed=true
      ok "Ubuntu package already installed via winget ($ubuntu_pkg)"
      break
    elif $WINGET install --id "$ubuntu_pkg" --exact --accept-source-agreements --accept-package-agreements >/dev/null 2>>"$LOG"; then
      ubuntu_installed=true
      ok "Ubuntu package installed via winget ($ubuntu_pkg)"
      break
    fi
  done
  if ! $ubuntu_installed; then
    fail "Ubuntu package install via winget failed"
    return 1
  fi

  if wsl_has_ubuntu; then
    ok "Ubuntu already registered in WSL"
  elif wsl.exe --install -d Ubuntu >/dev/null 2>>"$LOG" || wsl_has_ubuntu; then
    ok "Ubuntu registered in WSL"
  else
    fail "Ubuntu registration in WSL failed (restart may be required, then run: wsl --install -d Ubuntu)"
  fi
}

bootstrap_windows() {
  log "Detected Windows — using winget-based bootstrap"
  if ! command -v "$WINGET" &>/dev/null; then
    fail "winget not found. Install App Installer from Microsoft Store and re-run."
    return 1
  fi
  ok "winget available"

  # Start WSL + Ubuntu setup in the background so it runs in parallel with the
  # winget package and PowerShell module installs below.
  local wsl_out wsl_pid=""
  wsl_out="$(mktemp)"
  if ! $DRY_RUN; then
    log "Windows Subsystem for Linux (WSL) + Ubuntu... [running in background]"
    _wsl_setup >"$wsl_out" 2>&1 &
    wsl_pid=$!
  fi

  log "Installing winget packages from dotfiles/Wingetfile..."
  if [[ ! -f "$WINGET_FILE" ]]; then
    fail "Missing $WINGET_FILE"
    return 1
  elif $DRY_RUN; then
    while IFS= read -r pkg; do
      pkg="${pkg//$'\r'/}"
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      dry "winget install --id $pkg --exact --accept-source-agreements --accept-package-agreements"
    done < "$WINGET_FILE"
  else
    while IFS= read -r pkg; do
      pkg="${pkg//$'\r'/}"
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      install_winget_pkg "$pkg"
    done < "$WINGET_FILE"
  fi

  # Wait for WSL before using powershell.exe — wsl.exe activity can
  # temporarily disrupt WSL interop if allowed to race with .exe calls.
  if [[ -n "$wsl_pid" ]]; then
    log "Windows Subsystem for Linux (WSL) + Ubuntu... [waiting]"
    wait "$wsl_pid"
    cat "$wsl_out"
    wsl_pid=""
  fi

  log "Installing PowerShell modules..."
  if $DRY_RUN; then
    dry "Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber"
    dry "Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Repository PSGallery -Force -AllowClobber"
  else
    install_powershell_module "Az"
    install_powershell_module "Microsoft.WinGet.Client"
  fi

  log "Windows settings..."
  if $DRY_RUN; then
    dry "run scripts/windows.ps1 (taskbar, Caps Lock, PowerToys Run hotkey)"
  elif powershell.exe -NoProfile -NonInteractive -File "$REPO_DIR/scripts/windows.ps1" >>"$LOG" 2>&1; then
    ok "Windows settings"
  else
    fail "Windows settings (check scripts/windows.ps1)"
  fi

  if $DRY_RUN; then
    log "Windows Subsystem for Linux (WSL) + Ubuntu..."
    dry "wsl --install --no-distribution"
    dry "$WINGET install --id Canonical.Ubuntu --exact --accept-source-agreements --accept-package-agreements"
    dry "wsl --install -d Ubuntu"
  fi
  rm -f "$wsl_out"

  echo ""
  if ! $DRY_RUN; then
    failure_count=$(grep -c "^\[FAILED\]" "$LOG" 2>/dev/null || true)
    failure_count="${failure_count:-0}"
    if [[ "$failure_count" -gt 0 ]]; then
      printf '\e[1;31m%s failure(s) — see log.txt\e[0m\n' "$failure_count"
      grep "^\[FAILED\]" "$LOG"
      return 1
    else
      printf '\e[1;32mWindows bootstrap completed successfully\e[0m\n'
      return 0
    fi
  else
    printf '\e[1;33mDry run complete — run without --dry-run to apply.\e[0m\n'
    return 0
  fi
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
BOOTSTRAP_FAILED=0
if [[ "$OS_TYPE" == "windows" ]]; then
  bootstrap_windows || BOOTSTRAP_FAILED=$?
elif [[ "$OS_TYPE" == "unsupported" ]]; then
  fail "Unsupported OS. This bootstrap currently supports macOS and Windows."
  exit 1
fi

# ── Interactive prompts ───────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && ! $DRY_RUN; then
  printf '\e[1;36m==>\e[0m Setup — answer a few questions or press Enter for defaults\n'
  read -rp "  SSH key email/comment (leave blank for none): " SSH_EMAIL
  read -rp "  Change macOS hostname? [y/N]: " change_hostname
  if [[ "$change_hostname" =~ ^[Yy] ]]; then
    read -rp "  New hostname: " MAC_HOSTNAME
    export MAC_HOSTNAME
  fi
  echo ""
fi

# ── Xcode Command Line Tools ──────────────────────────────────────────────────
XCODE_CLT_OK=0
if [[ "$OS_TYPE" == "macos" ]]; then
  log "Checking Xcode Command Line Tools..."
  if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools (already installed)"
    XCODE_CLT_OK=1
  elif $DRY_RUN; then
    dry "install Xcode Command Line Tools"
    XCODE_CLT_OK=1
  else
    xcode-select --install
    read -rp "Press Enter once the Xcode CLT installation is complete..."
    if xcode-select -p &>/dev/null; then
      ok "Xcode Command Line Tools"
      XCODE_CLT_OK=1
    else
      fail "Xcode Command Line Tools"
    fi
  fi
fi

# ── Homebrew ──────────────────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && [[ "$XCODE_CLT_OK" == "1" ]]; then
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
      BOOTSTRAP_FAILED=1
    fi
  fi
elif [[ "$OS_TYPE" == "macos" ]]; then
  fail "Skipping Homebrew (Xcode CLT required)"
fi

# ── Brewfile ──────────────────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && [[ "$XCODE_CLT_OK" == "1" ]] && command -v brew &>/dev/null; then
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
fi

# ── oh-my-posh — trust binary (macOS Gatekeeper) ─────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && [[ "$XCODE_CLT_OK" == "1" ]]; then
  log "Trusting oh-my-posh binary..."
  if $DRY_RUN; then
    dry "xattr -dr com.apple.quarantine $(brew --prefix)/bin/oh-my-posh"
  elif command -v oh-my-posh &>/dev/null; then
    xattr -dr com.apple.quarantine "$(brew --prefix)/bin/oh-my-posh" 2>/dev/null && ok "oh-my-posh trusted" || ok "oh-my-posh (no quarantine attribute)"
  else
    fail "oh-my-posh (command not found — was brew bundle successful?)"
  fi
fi

# ── Ollama — pull models ──────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && [[ "$XCODE_CLT_OK" == "1" ]]; then
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
fi

# ── Rancher Desktop — docker on PATH ─────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && [[ "$XCODE_CLT_OK" == "1" ]]; then
  log "Checking docker on PATH (Rancher Desktop)..."
  if command -v docker &>/dev/null; then
    ok "docker is on PATH (Rancher Desktop driver available)"
  elif $DRY_RUN; then
    dry "verify docker is on PATH — open Rancher Desktop and enable dockerd (moby) in Preferences → Container Engine"
  else
    fail "docker not on PATH — open Rancher Desktop, enable dockerd (moby) in Preferences → Container Engine, then re-run"
  fi
fi

# ── minikube default driver ───────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]] && [[ "$XCODE_CLT_OK" == "1" ]]; then
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
fi

# ── Fonts ─────────────────────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]]; then
  log "CascadiaMono fonts..."
  if $DRY_RUN; then
    dry "copy CascadiaMono/*.ttf to ~/Library/Fonts/"
  elif cp "$REPO_DIR/CascadiaMono/"*.ttf "$HOME/Library/Fonts/" 2>/dev/null; then
    ok "CascadiaMono fonts"
  else
    fail "CascadiaMono fonts (copy failed)"
  fi
fi

# ── SSH key ───────────────────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]]; then
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
      ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null || true

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

# ── proto config + tool install (Windows) ─────────────────────────────────────
if [[ "$OS_TYPE" == "windows" ]]; then
  PROTO_DIR="$HOME/.proto"
  log "proto config..."
  if $DRY_RUN; then
    dry "link ~/.proto/.prototools -> $REPO_DIR/proto/.prototools"
    dry "run 'proto install' to fetch Python, Node, Java"
  else
    mkdir -p "$PROTO_DIR"
    if backup_and_link "$REPO_DIR/proto/.prototools" "$PROTO_DIR/.prototools"; then
      ok "Symlink proto .prototools"
    else
      fail "Symlink proto .prototools"
    fi
    if command -v proto &>/dev/null; then
      log "Installing tools listed in proto/.prototools (Python, Node, Java)..."
      if proto install --yes; then
        ok "proto tools installed"
        log "Installed runtimes:"
        proto list --installed | sed 's/^/  /' | tee -a "$LOG"
      else
        fail "proto install (run 'proto install' manually to retry)"
      fi
    else
      fail "proto (command not found — was winget package installed?)"
    fi
  fi
fi

# ── mise config + tool install (macOS) ─────────────────────────────────────────
if [[ "$OS_TYPE" == "macos" ]]; then
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

# ── WezTerm config symlink ────────────────────────────────────────────────────
WEZTERM_FILE="$HOME/.wezterm.lua"
log "WezTerm config..."
if $DRY_RUN; then
  dry "link WezTerm config -> $REPO_DIR/wezterm/wezterm.lua"
else
  if backup_and_link "$REPO_DIR/wezterm/wezterm.lua" "$WEZTERM_FILE"; then
    ok "Symlink WezTerm config"
  else
    fail "Symlink WezTerm config"
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
if [[ "$OS_TYPE" == "macos" ]]; then
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
  if [[ "$failure_count" -gt 0 ]] || [[ "$BOOTSTRAP_FAILED" -ne 0 ]]; then
    printf '\e[1;31m%s failure(s) — see log.txt\e[0m\n' "$((failure_count + BOOTSTRAP_FAILED))"
    grep "^\[FAILED\]" "$LOG"
    exit 1
  else
    printf '\e[1;32mAll steps completed successfully\e[0m\n'
  fi
  echo ""
  log "Bootstrap complete. Open a new terminal to apply shell changes."
  log "Some macOS settings require a logout or restart."
fi
