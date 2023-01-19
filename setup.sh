#!/bin/zsh

if [[ "$OSTYPE" == "darwin"* ]]; then
    # install brew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # setup brew for use
    echo '# Set PATH, MANPATH, etc., for Homebrew.' >> ${HOME}/.zprofile\
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ${HOME}/.zprofile\
    eval "$(/opt/homebrew/bin/brew shellenv)"

    # install software I use
    brew update
    brew install starship git bash htop copyq ripgrep scroll-reverser

    mkdir -p ${HOME}/.config
    cp starship.toml ${HOME}/.config/

    # Enable Dock Autohide
    defaults write com.apple.dock autohide -int 1
    # remove dock hide delay
    defaults write com.apple.Dock autohide-delay -float 0.0001; killall Dock
    # disable recent applications
    defaults write com.apple.dock show-recents -bool FALSE

    #Enable tap to click
    sudo defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    sudo defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    sudo defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    sudo defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    
    # Dark Mode
    osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'

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
