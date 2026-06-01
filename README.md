# devsetup

Reproducible Mac setup for a software/data engineering environment.

## Quick Start

```bash
git clone git@github.com:WDI-Json/devsetup.git ~/GITHUB/devsetup
cd ~/GITHUB/devsetup
bash bootstrap.sh --dry-run   # controleer eerst wat er gaat gebeuren
bash bootstrap.sh             # voer daarna echt uit
```

> Op een gloednieuwe Mac: installeer Xcode CLT wanneer daarom gevraagd wordt en wacht tot dat klaar is voordat het script verdergaat.

Na afloop staat in `log.txt` welke stappen geslaagd of mislukt zijn.

## Structure

```
├── bootstrap.sh          # Main installer — run this once
├── dotfiles/
│   ├── .zshrc            # Shell config (symlinked to ~/.zshrc)
│   └── Brewfile          # All CLI tools and apps via Homebrew
├── vscode/
│   ├── settings.json     # VS Code user settings (symlinked)
│   ├── keybindings.json  # VS Code keybindings (symlinked)
│   └── extensions.txt    # Extensions installed via code --install-extension
├── scripts/
│   ├── macos.sh          # macOS system defaults
│   ├── dock.sh           # Dock layout via dockutil
│   └── repos.sh          # Clone personal GitHub repositories
└── CascadiaMono/         # Fonts (copied to ~/Library/Fonts)
```

## What bootstrap.sh does

1. Install Xcode Command Line Tools (if missing)
2. Install Homebrew (if missing)
3. `brew bundle` — install all packages, casks, and VS Code extensions
4. Copy CascadiaMono fonts to `~/Library/Fonts`
5. Generate SSH key and prompt to add it to GitHub (if missing)
6. Symlink `~/.zshrc` → `dotfiles/.zshrc`
7. Symlink VS Code settings and keybindings
8. Install VS Code extensions from `vscode/extensions.txt`
9. Apply macOS system settings via `scripts/macos.sh`
10. Configure Dock via `scripts/dock.sh`
11. Clone personal repositories via `scripts/repos.sh`

## Symlinks

Changes to dotfiles in this repo take effect immediately since the live config files are symlinks back into the repo.

| Symlink target | Source in repo |
|---|---|
| `~/.zshrc` | `dotfiles/.zshrc` |
| `~/Library/Application Support/Code/User/settings.json` | `vscode/settings.json` |
| `~/Library/Application Support/Code/User/keybindings.json` | `vscode/keybindings.json` |

## Adding repos

Edit `scripts/repos.sh` and add a `clone_or_update "repo-name"` line.

## Dry-run

De dry-run installeert niets, maar laat wel zien wat er zou gebeuren. Hij leest de huidige staat van je Mac — wat al geïnstalleerd is, welke repos al bestaan — en toont alleen de acties die daadwerkelijk iets zouden veranderen.

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

- `rancher` cask: verify the exact name with `brew search rancher` if installation fails
- Dock: apps are skipped silently if not installed yet — re-run `scripts/dock.sh` after installing
- Some macOS settings (keyboard repeat, dark mode) require a logout to take effect
