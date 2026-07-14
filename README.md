# devsetup

Reproducible setup for a software/data engineering environment on macOS and Windows.

## Quick Start

```bash
git clone git@github.com:WDI-Json/devsetup.git ~/GITHUB/devsetup
cd ~/GITHUB/devsetup
bash bootstrap.sh --dry-run   # controleer eerst wat er gaat gebeuren
bash bootstrap.sh             # voer daarna echt uit
```

> macOS: installeer Xcode CLT wanneer daarom gevraagd wordt en wacht tot dat klaar is voordat het script verdergaat.
>
> Windows: run het script vanuit een Bash-shell (bijv. Git Bash). `bootstrap.sh` gebruikt automatisch `winget` en probeert ook WSL + Ubuntu te installeren.

Na afloop staat in `log.txt` welke stappen geslaagd of mislukt zijn.
Windows package parity-validatie wordt apart bijgehouden in `windows-package-validation.log`.

## Platform distinction

| Platform | Package manager | Bootstrap path |
|---|---|---|
| macOS | Homebrew (`dotfiles/Brewfile`) | volledige macOS setup (dotfiles, symlinks, macOS instellingen, Dock, repos) |
| Windows | winget (`dotfiles/Wingetfile`) | winget installaties + WSL/Ubuntu setup |

## Structure

```
├── bootstrap.sh          # Main installer — run this once
├── dotfiles/
│   ├── .zshrc            # Shell config (symlinked to ~/.zshrc)
│   ├── Brewfile          # All CLI tools and apps via Homebrew
│   └── Wingetfile        # Core Windows packages via winget
├── vscode/
│   ├── settings.json     # VS Code user settings (symlinked)
│   ├── keybindings.json  # VS Code keybindings (symlinked)
│   └── extensions.txt    # Extensions installed via code --install-extension
├── neovim/               # Neovim config (symlinked to ~/.config/nvim)
├── wezterm/
│   └── wezterm.lua       # WezTerm config (symlinked)
├── mise/
│   └── config.toml       # mise tool versions: Python, Node, Java LTS
├── scripts/
│   ├── macos.sh          # macOS system defaults
│   ├── dock.sh           # Dock layout via dockutil
│   └── repos.sh          # Clone personal GitHub repositories
├── hooks/
│   └── commit-msg        # Enforces "setup: " or "vim: " prefix
└── CascadiaMono/         # Fonts (copied to ~/Library/Fonts)
```

## What bootstrap.sh does

The script auto-detects your OS:

- **macOS**: runs the original Homebrew/macOS flow
- **Windows**: runs a winget-based flow and attempts WSL + Ubuntu setup

### macOS flow

1. Install Xcode Command Line Tools (if missing)
2. Install Homebrew (if missing)
3. `brew bundle` — install packages and casks from `dotfiles/Brewfile`
4. Copy CascadiaMono fonts to `~/Library/Fonts`
5. Generate SSH key and prompt to add it to GitHub (if missing)
6. Symlink `~/.zshrc` → `dotfiles/.zshrc`
7. Symlink VS Code settings and keybindings
8. Install VS Code extensions from `vscode/extensions.txt`
9. Apply macOS system settings via `scripts/macos.sh`
10. Configure Dock via `scripts/dock.sh`
11. Clone personal repositories via `scripts/repos.sh`

### Windows flow

1. Check `winget` availability
2. Install packages listed in `dotfiles/Wingetfile`
3. Install PowerShell modules: `Az` and `Microsoft.WinGet.Client`
4. Enable/install WSL where needed
5. Install Ubuntu (via winget) and attempt WSL Ubuntu registration

## Symlinks

Changes to dotfiles in this repo take effect immediately since the live config files are symlinks back into the repo.

| Platform | Symlink target | Source in repo |
|---|---|---|
| macOS | `~/.zshrc` | `dotfiles/.zshrc` |
| macOS | `~/Library/Application Support/Code/User/settings.json` | `vscode/settings.json` |
| macOS | `~/Library/Application Support/Code/User/keybindings.json` | `vscode/keybindings.json` |
| macOS | `~/.config/nvim` | `neovim/` |
| macOS | `~/.wezterm.lua` | `wezterm/wezterm.lua` |
| macOS | `~/.config/mise/config.toml` | `mise/config.toml` |
| macOS/Windows | `.git/hooks/commit-msg` | `hooks/commit-msg` |

## Commit convention

This repo enforces a prefix on every commit message:
- `setup: ` — devsetup work (bootstrap, dotfiles, Brewfile, scripts)
- `vim: ` — neovim config changes (`neovim/` directory)

The `hooks/commit-msg` hook rejects commits without one of these prefixes. Merge and revert commits are exempt.

## Adding repos

Edit `scripts/repos.sh` and add a `clone_or_update "repo-name"` line.

## Language runtimes (mise)

`mise` manages Python, Node and Java versions and activates them in every shell. `mise/config.toml` pins the major LTS versions; mise picks the newest patch automatically.

Current pins:
- Python `3.14`
- Node `24` (LTS)
- Java `temurin-21` (LTS)

To bump a version:
```bash
# Edit the symlinked config (changes go straight into the repo)
$EDITOR ~/.config/mise/config.toml
mise install   # fetch the new version
```

To switch versions per project, drop a local `mise.toml` (or `.tool-versions`) in the project root — mise prefers the closest config.

## Dry-run

De dry-run installeert niets, maar laat wel zien wat er zou gebeuren. Hij leest de huidige staat van je platform (macOS of Windows) en toont alleen de acties die daadwerkelijk iets zouden veranderen.

```bash
bash bootstrap.sh --dry-run
```

Voorbeeld output:
```
=== DRY RUN — no changes will be made ===

==> Checking Brewfile packages...
  would: brew "duckdb" is not installed.
  would: cask "rancher" is not installed.
==> Dotfile symlinks...
  would: link ~/.zshrc -> …/dotfiles/.zshrc
==> Repositories...
  would: git clone git@github.com:WDI-Json/neovim_config.git -> ~/GITHUB/neovim_config

Dry run complete — run without --dry-run to apply.
```

## Notes

- macOS:
  - `rancher` cask: verify the exact name with `brew search rancher` if installation fails
  - Dock: apps are skipped silently if not installed yet — re-run `scripts/dock.sh` after installing
  - Some macOS settings (keyboard repeat, dark mode) require a logout to take effect
- Windows:
  - `winget` (App Installer) must be available
  - WSL/Ubuntu setup may require an elevated shell and/or restart before first use
