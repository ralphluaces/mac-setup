#!/bin/zsh

if [[ "$OSTYPE" == "darwin"* ]]; then
    # install brew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # install software I use
    brew update
    brew install starship git bash htop

    # Enable Dock Autohide
    defaults write com.apple.dock autohide -int 1
    # remove dock hide delay
    defaults write com.apple.Dock autohide-delay -float 0.0001; killall Dock

    # Enable battery Percent
    defaults write ${HOME}/Library/Preferences/ByHost/com.apple.controlcenter.plist BatteryShowPercentage -bool true

    # Disable Look up & data detectors: Tap with three fingers
    defaults write com.apple.AppleMultitouchTrackpad ActuateDetents -bool false

    # Restart UI Elements after Changes
    for APP in \
      "Activity Monitor" \
      "SystemUIServer" \
      "Dock" \
      "NotificationCenter"
    do
	killall "${APP}" &> /dev/null
    done
fi

rm -rf ~/.zshrc
cp ./zshrc ~/.zshrc