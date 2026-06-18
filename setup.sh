#!/bin/zsh

log()  { echo "\033[1;34m==>\033[0m $*"; }
ok()   { echo "\033[1;32m  ✓\033[0m $*"; }
warn() { echo "\033[1;33m  !\033[0m $*"; }

spin() {
    local label="$1"
    shift
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    "$@" &>/tmp/mac-setup-spin.log &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        printf "\r  \033[1;34m%s\033[0m  %s" "${frames[$((i % 10))]}" "$label"
        i=$((i + 1))
        sleep 0.08
    done

    wait $pid
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\033[1;32m  ✓\033[0m  %s\n" "$label"
    else
        printf "\r\033[1;31m  ✗\033[0m  %s (see /tmp/mac-setup-spin.log)\n" "$label"
        return $exit_code
    fi
}

echo ""
echo "This script will configure your Mac, install Homebrew packages, and overwrite your .zshrc."
echo ""
read "REPLY?Proceed? (y/N) "
echo ""
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    warn "Aborted."
    exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    log "Homebrew"
    spin "Installing Homebrew" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if ! grep -q 'brew shellenv' ${HOME}/.zprofile 2>/dev/null; then
        echo '# Set PATH, MANPATH, etc., for Homebrew.' >> ${HOME}/.zprofile
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ${HOME}/.zprofile
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"

    log "Packages"
    spin "Updating Homebrew" brew update
    spin "Installing formulae" brew install starship git bash htop ripgrep zsh-autosuggestions fzf gh jq tree watch awscli tfenv nvm
    spin "Installing casks" brew install --cask ghostty maccy stats obsidian visual-studio-code tailscale scroll-reverser
    spin "Configuring fzf key bindings" "$(brew --prefix)/opt/fzf/install" --all --no-update-rc --no-bash --no-fish

    log "Config files"
    spin "Copying config files" zsh -c "
        mkdir -p ${HOME}/.config
        cp starship.toml ${HOME}/.config/
        cp aws-prompt.py ${HOME}/.config/
        mkdir -p '${HOME}/Library/Application Support/com.mitchellh.ghostty'
        cp ghostty.conf '${HOME}/Library/Application Support/com.mitchellh.ghostty/config.ghostty'
    "

    log "System preferences"
    spin "Configuring Dock" zsh -c "
        defaults write com.apple.dock autohide -int 1
        defaults write com.apple.Dock autohide-delay -float 0.0001
        defaults write com.apple.dock show-recents -bool false
        defaults write com.apple.dock tilesize -int 67
        defaults write com.apple.dock wvous-bl-corner -int 5
        defaults write com.apple.dock wvous-bl-modifier -int 0
        defaults write com.apple.dock wvous-br-corner -int 14
        defaults write com.apple.dock wvous-br-modifier -int 0
    "
    spin "Configuring Finder" zsh -c "
        defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
        defaults write com.apple.finder FXPreferredViewStyle -string 'Nlsv'
        defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
        defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
        defaults write com.apple.finder FXICloudDriveDesktop -bool false
        defaults write com.apple.finder FXICloudDriveDocuments -bool false
        defaults write com.apple.finder AppleShowAllFiles -bool true
        defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    "
    spin "Configuring keyboard & input" zsh -c "
        defaults write NSGlobalDomain KeyRepeat -int 2
        defaults write NSGlobalDomain InitialKeyRepeat -int 15
        defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
        defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
        defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
        defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
        defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
        defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    "
    spin "Configuring Spaces" zsh -c "
        defaults write com.apple.spaces spans-displays -bool false
    "
    spin "Configuring trackpad" zsh -c "
        sudo defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
        sudo defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
        sudo defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
        sudo defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
        defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
    "
    spin "Configuring menu bar & system UI" zsh -c "
        defaults write com.apple.menuextra.clock ShowAMPM -bool true
        defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
        defaults write com.apple.menuextra.clock ShowSeconds -bool true
        defaults write com.apple.menuextra.clock ShowDate -bool false
        defaults write com.apple.screencapture style -string 'selection'
        defaults write ${HOME}/Library/Preferences/ByHost/com.apple.controlcenter.plist BatteryShowPercentage -bool true
        osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'
    "
    spin "Restarting UI components" zsh -c "
        for APP in 'Activity Monitor' 'SystemUIServer' 'Dock' 'NotificationCenter' 'Finder'; do
            killall \"\$APP\" &>/dev/null
        done
        true
    "

    log "Security"
    spin "Enabling Touch ID for sudo" zsh -c "
        if ! grep -q 'pam_tid' /etc/pam.d/sudo; then
            sudo sed -i '' '1a\\
auth       sufficient     pam_tid.so
' /etc/pam.d/sudo
        fi
    "
fi

log "Shell config"

MARKER_START="# BEGIN mac-setup managed block"
MARKER_END="# END mac-setup managed block"

install_shell_file() {
    local src="$1"
    local dest="$2"
    local block
    block="$MARKER_START
$(cat $src)
$MARKER_END"

    if [[ ! -f "$dest" ]]; then
        echo "$block" > "$dest"
        ok "Installed $dest"
    elif grep -q "$MARKER_START" "$dest"; then
        # Replace existing managed block, preserve everything outside it
        local tmp=$(mktemp)
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v block="$block" '
            $0==start { print block; skip=1; next }
            $0==end   { skip=0; next }
            !skip     { print }
        ' "$dest" > "$tmp" && mv "$tmp" "$dest"
        ok "Updated managed block in $dest"
    else
        # File exists but has no marker — append the managed block
        echo "" >> "$dest"
        echo "$block" >> "$dest"
        ok "Appended managed block to $dest"
    fi
}

install_shell_file ./zshrc ~/.zshrc
install_shell_file ./zprofile ~/.zprofile

echo ""
echo "\033[1;32mSetup complete.\033[0m"
