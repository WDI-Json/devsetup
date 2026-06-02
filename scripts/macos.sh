#!/usr/bin/env bash
set -euo pipefail

# Device name (only changed if MAC_HOSTNAME is set; leave current name otherwise)
if [[ -n "${MAC_HOSTNAME:-}" ]]; then
  sudo scutil --set ComputerName "$MAC_HOSTNAME"
  sudo scutil --set HostName "$MAC_HOSTNAME"
  sudo scutil --set LocalHostName "$MAC_HOSTNAME"
fi

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64

# Finder
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Screenshots
defaults write com.apple.screencapture location -string "$HOME/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Mouse & Trackpad (mirrors current setup)
# Tracking speed and force click
defaults write NSGlobalDomain com.apple.mouse.scaling -float 2
defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool true

# Trackpad: physical click only (no tap-to-click)
defaults write com.apple.AppleMultitouchTrackpad Clicking -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -int 0

# Trackpad: right-click via bottom-right corner, not two-finger
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2

# No three-finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -int 0

# Magic Mouse: two-button mode (right click as secondary)
defaults write com.apple.AppleMultitouchMouse MouseButtonMode -string TwoButton

# Auto dark/light mode
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true

for app in "Finder" "SystemUIServer" "Dock"; do
  killall "$app" &>/dev/null || true
done

echo "macOS settings applied."
