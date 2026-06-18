#!/bin/zsh

SHELL_ONLY=false
BREW_ONLY=false
NO_SUDO=false
AS_ROOT=false
GIT_DIR=""

# Auto-detect if running as root/sudo without --root flag
if [[ $EUID -eq 0 ]]; then
    AS_ROOT=true
fi

for arg in "$@"; do
    [[ "$arg" == "--shell" ]]         && SHELL_ONLY=true
    [[ "$arg" == "--brew" ]]          && BREW_ONLY=true
    [[ "$arg" == "--nosudo" ]]        && NO_SUDO=true
    [[ "$arg" == "--root" ]]          && AS_ROOT=true
    [[ "$arg" == --git-dir=* ]]       && GIT_DIR="${arg#--git-dir=}"
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        echo ""
        echo "Usage: ./setup.sh [options]"
        echo ""
        echo "  (no args)          Full setup: Homebrew, packages, config files, system preferences, shell config"
        echo "  --brew             Install/update Homebrew and packages only"
        echo "  --shell            Update ~/.zshrc and ~/.zprofile managed blocks only"
        echo "  --nosudo           Skip steps that require sudo (trackpad tap-to-click, Touch ID for sudo)"
        echo "  --root             Run as root (also auto-detected when invoked with sudo)"
        echo "  --git-dir=PATH     Set the git repos directory (default: ~, prompted if not set)"
        echo "  --help             Show this help"
        echo ""
        exit 0
    fi
done

echo ""
echo "\033[1;34m  mac-setup\033[0m"
echo ""

if $AS_ROOT; then
    echo "  \033[1;33mRunning as root.\033[0m Target user will be detected from SUDO_USER or prompted."
fi

if $SHELL_ONLY; then
    echo "  Mode:     shell only"
    echo "  Updates:  ~/.zshrc and ~/.zprofile managed blocks"
elif $BREW_ONLY; then
    echo "  Mode:     brew only"
    echo "  Updates:  Homebrew install + packages"
else
    echo "  Mode:     full setup"
    echo "  Steps:    Xcode CLI tools, Homebrew + packages, config files, system preferences, shell config"
    if $NO_SUDO; then
        echo "  Sudo:     skipped (trackpad tap-to-click and Touch ID will not be configured)"
    fi
fi
echo ""
read "REPLY?Proceed? (y/N) "
echo ""
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Determine target user — when running as root we configure a real user's environment
if $AS_ROOT; then
    if [[ -n "$SUDO_USER" ]]; then
        TARGET_USER="$SUDO_USER"
        echo "  Configuring for user: $TARGET_USER (detected from SUDO_USER)"
    else
        read "TARGET_USER?Username to configure (not root): "
    fi
else
    TARGET_USER="$USER"
fi
TARGET_HOME=$(eval echo "~$TARGET_USER")
export TARGET_HOME TARGET_USER

if [[ -z "$GIT_DIR" ]]; then
    read "GIT_DIR?Git repos directory [$TARGET_HOME]: "
    GIT_DIR="${GIT_DIR:-$TARGET_HOME}"
fi
GIT_DIR="${GIT_DIR/#\~/$TARGET_HOME}"
if [[ "$GIT_DIR" != "$TARGET_HOME" ]]; then
    mkdir -p "$GIT_DIR"
    $AS_ROOT && chown "$TARGET_USER" "$GIT_DIR"
fi

# Ensure Xcode CLI tools are installed (required for git, make, and Homebrew)
if ! xcode-select -p &>/dev/null; then
    echo ""
    echo "  Xcode Command Line Tools not found — installing now."
    echo "  A dialog will appear; click Install and wait for it to complete."
    xcode-select --install
    echo "  Waiting for Xcode CLI tools installation to complete..."
    until xcode-select -p &>/dev/null; do sleep 5; done
    echo "  Xcode CLI tools installed."
fi

LOGFILE="$(pwd)/mac-setup.log"
# Strip ANSI escape codes and spinner animation lines when writing to log
_log_filter() {
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b[()[]*[0-9;]*[a-zA-Z]//g; s/\r//g' \
    | grep -v '^[[:space:]]*[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏][[:space:]]' \
    >> "$LOGFILE"
}
exec > >(tee >(_log_filter)) 2>&1
echo "=== mac-setup run: $(date) ===" >> "$LOGFILE"

log()  { echo "\033[1;34m==>\033[0m $*"; }
ok()   { echo "\033[1;32m  ✓\033[0m $*"; }
warn() { echo "\033[1;33m  !\033[0m $*"; }

# Run a command as TARGET_USER — passthrough when already running as that user
run_as_user() {
    if $AS_ROOT; then
        sudo -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

spin() {
    local label="$1"
    shift
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    "$@" &>>"$LOGFILE" &
    local pid=$!

    # Animation goes to /dev/tty only — never touches the log
    while kill -0 $pid 2>/dev/null; do
        printf "\r  \033[1;34m%s\033[0m  %s" "${frames[$((i % 10))]}" "$label" >/dev/tty
        i=$((i + 1))
        sleep 0.08
    done
    printf "\r\033[2K" >/dev/tty  # clear spinner line before printing final status to stdout

    wait $pid
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        printf "\033[1;32m  ✓\033[0m  %s\n" "$label"
    else
        printf "\033[1;31m  ✗\033[0m  %s (see mac-setup.log)\n" "$label"
        return $exit_code
    fi
}

# Like spin() but shows a rolling window of command output below the header.
brew_spin() {
    local label="$1"
    shift
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local tmpfile=$(mktemp)
    local exit_code_file=$(mktemp)
    local ROWS=5

    # All animation goes to /dev/tty — only the final status line hits stdout/log
    printf "  \033[1;34m%s\033[0m  %s\n" "${frames[0]}" "$label" >/dev/tty
    for ((j=0; j<ROWS; j++)); do printf "\n" >/dev/tty; done

    ({ "$@"; echo $? >"$exit_code_file"; } 2>&1 | tee >(_log_filter) >"$tmpfile") &
    local pid=$!

    _bspin_render() {
        local lines=()
        while IFS= read -r line; do lines+=("$line"); done < <(tail -n $ROWS "$tmpfile" 2>/dev/null)
        while (( ${#lines[@]} < ROWS )); do lines+=(""); done

        {
            printf "\033[${ROWS}A"
            for line in "${lines[@]}"; do
                printf "\033[2K    \033[2m%.120s\033[0m\n" "$line"
            done
            printf "\033[$((ROWS+1))A\r  \033[1;34m%s\033[0m  %-50s\033[${ROWS}B\n" \
                "${frames[$((i % 10))]}" "$label"
        } >/dev/tty
    }

    while kill -0 $pid 2>/dev/null; do
        _bspin_render
        (( i++ ))
        sleep 0.1
    done
    wait $pid
    _bspin_render

    local exit_code=$(cat "$exit_code_file" 2>/dev/null || echo 1)

    # Clear the animation block from the terminal
    {
        printf "\033[$((ROWS+1))A\r"
        for ((j=0; j<=ROWS; j++)); do printf "\033[2K\n"; done
        printf "\033[$((ROWS+1))A"
    } >/dev/tty

    # Print final status to stdout so it hits the log
    if [[ "$exit_code" == "0" ]]; then
        printf "\033[1;32m  ✓\033[0m  %s\n" "$label"
    else
        printf "\033[1;31m  ✗\033[0m  %s (see mac-setup.log)\n" "$label"
    fi

    unfunction _bspin_render 2>/dev/null
    rm -f "$tmpfile" "$exit_code_file"
    return $exit_code
}

# System preference helper functions — all user-space writes run as TARGET_USER
_cfg_copy_files() {
    mkdir -p "$TARGET_HOME/.config"
    cp starship.toml "$TARGET_HOME/.config/"
    cp aws-prompt.py "$TARGET_HOME/.config/"
    mkdir -p "$TARGET_HOME/Library/Application Support/com.mitchellh.ghostty"
    cp ghostty.conf "$TARGET_HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
    if $AS_ROOT; then
        chown "$TARGET_USER" "$TARGET_HOME/.config/starship.toml"
        chown "$TARGET_USER" "$TARGET_HOME/.config/aws-prompt.py"
        chown "$TARGET_USER" "$TARGET_HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
    fi
}
_cfg_dock() {
    run_as_user defaults write com.apple.dock autohide -int 1
    run_as_user defaults write com.apple.Dock autohide-delay -float 0.0001
    run_as_user defaults write com.apple.dock show-recents -bool false
    run_as_user defaults write com.apple.dock tilesize -int 67
    run_as_user defaults write com.apple.dock wvous-bl-corner -int 5
    run_as_user defaults write com.apple.dock wvous-bl-modifier -int 0
    run_as_user defaults write com.apple.dock wvous-br-corner -int 14
    run_as_user defaults write com.apple.dock wvous-br-modifier -int 0
}
_cfg_finder() {
    run_as_user defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
    run_as_user defaults write com.apple.finder FXPreferredViewStyle -string 'Nlsv'
    run_as_user defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    run_as_user defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
    run_as_user defaults write com.apple.finder FXICloudDriveDesktop -bool false
    run_as_user defaults write com.apple.finder FXICloudDriveDocuments -bool false
    run_as_user defaults write com.apple.finder AppleShowAllFiles -bool true
    run_as_user defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    # Show Macintosh HD in Finder sidebar Locations section
    run_as_user defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
    run_as_user defaults write com.apple.finder SidebarShowingSignedIntoiCloud -bool false
    run_as_user defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
    run_as_user defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
    run_as_user sfltool add-item com.apple.LSSharedFileList.FavoriteVolumes "file:///Volumes/Macintosh HD" 2>/dev/null || true
    # Add home folder to Finder sidebar Favorites
    run_as_user sfltool add-item com.apple.LSSharedFileList.FavoriteItems "file://$TARGET_HOME/" 2>/dev/null || true
}
_cfg_keyboard() {
    run_as_user defaults write NSGlobalDomain KeyRepeat -int 2
    run_as_user defaults write NSGlobalDomain InitialKeyRepeat -int 15
    run_as_user defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
    run_as_user defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
    run_as_user defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    run_as_user defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
    run_as_user defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    run_as_user defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    run_as_user defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    run_as_user defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
}
_cfg_spaces() {
    run_as_user defaults write com.apple.spaces spans-displays -bool false
}
_cfg_menubar() {
    run_as_user defaults write com.apple.menuextra.clock ShowAMPM -bool true
    run_as_user defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
    run_as_user defaults write com.apple.menuextra.clock ShowSeconds -bool true
    run_as_user defaults write com.apple.menuextra.clock ShowDate -bool false
    run_as_user defaults write com.apple.screencapture style -string 'selection'
    run_as_user defaults write "$TARGET_HOME/Library/Preferences/ByHost/com.apple.controlcenter.plist" BatteryShowPercentage -bool true
    run_as_user osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'
    # Maccy popup shortcut: Cmd+` (carbonModifiers=4096 = Cmd, carbonKeyCode=50 = `)
    run_as_user defaults write org.p0deje.Maccy "KeyboardShortcuts_popup" -string '{"carbonModifiers":4096,"carbonKeyCode":50}'
}
_cfg_restart_ui() {
    for APP in 'Activity Monitor' 'SystemUIServer' 'Dock' 'NotificationCenter' 'Finder'; do
        killall "$APP" &>/dev/null
    done
    true
}

if ! $SHELL_ONLY && [[ "$OSTYPE" == "darwin"* ]]; then
    log "Homebrew"
    # Check fixed path — root's PATH may not include /opt/homebrew/bin
    if ! /opt/homebrew/bin/brew --version &>/dev/null 2>&1; then
        echo "  Installing Homebrew (running as $TARGET_USER)..."
        run_as_user /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        ok "Homebrew already installed"
    fi
    if ! grep -q 'brew shellenv' "$TARGET_HOME/.zprofile" 2>/dev/null; then
        echo '# Set PATH, MANPATH, etc., for Homebrew.' >> "$TARGET_HOME/.zprofile"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$TARGET_HOME/.zprofile"
        $AS_ROOT && chown "$TARGET_USER" "$TARGET_HOME/.zprofile"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"

    log "Packages"
    brew_spin "Updating Homebrew" run_as_user brew update
    brew_spin "Installing formulae" run_as_user brew install starship git bash htop ripgrep zsh-autosuggestions fzf gh jq tree watch awscli tfenv nvm
    brew_spin "Installing casks" run_as_user brew install --cask --force ghostty maccy stats obsidian visual-studio-code tailscale scroll-reverser
    spin "Configuring fzf key bindings" run_as_user "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
fi

if ! $SHELL_ONLY && ! $BREW_ONLY && [[ "$OSTYPE" == "darwin"* ]]; then
    log "Config files"
    spin "Copying config files" _cfg_copy_files

    log "System preferences"
    spin "Configuring Dock" _cfg_dock
    spin "Configuring Finder" _cfg_finder
    spin "Configuring keyboard & input" _cfg_keyboard
    spin "Configuring Spaces" _cfg_spaces
    if $NO_SUDO; then
        warn "Skipping trackpad tap-to-click (requires sudo)"
    else
        sudo defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
        sudo defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
        sudo defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
        sudo defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
        run_as_user defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
        ok "Configuring trackpad"
    fi
    spin "Configuring menu bar & system UI" _cfg_menubar
    spin "Restarting UI components" _cfg_restart_ui

    log "Security"
    if $NO_SUDO; then
        warn "Skipping Touch ID for sudo (requires sudo)"
    else
        if ! grep -q 'pam_tid' /etc/pam.d/sudo; then
            sudo sed -i '' '1a\
auth       sufficient     pam_tid.so
' /etc/pam.d/sudo
        fi
        ok "Enabling Touch ID for sudo"
    fi
fi

if ! $BREW_ONLY; then
    log "Shell config"

    MARKER_START="# BEGIN mac-setup managed block"
    MARKER_END="# END mac-setup managed block"

    install_shell_file() {
        local src="$1"
        local dest="$TARGET_HOME/$2"
        local blockfile=$(mktemp)

        # Write the replacement block to a temp file, substituting __GIT_DIR__ placeholder
        printf '%s\n' "$MARKER_START" > "$blockfile"
        sed "s|__GIT_DIR__|$GIT_DIR|g" "$src" >> "$blockfile"
        printf '%s\n' "$MARKER_END" >> "$blockfile"

        if [[ ! -f "$dest" ]]; then
            cat "$blockfile" > "$dest"
            ok "Installed $dest"
        elif grep -q "$MARKER_START" "$dest"; then
            local tmp=$(mktemp)
            awk -v start="$MARKER_START" -v end="$MARKER_END" -v bf="$blockfile" '
                $0==start { while ((getline line < bf) > 0) print line; skip=1; next }
                $0==end   { skip=0; next }
                !skip     { print }
            ' "$dest" > "$tmp" && mv "$tmp" "$dest"
            ok "Updated managed block in $dest"
        else
            echo "" >> "$dest"
            cat "$blockfile" >> "$dest"
            ok "Appended managed block to $dest"
        fi
        $AS_ROOT && chown "$TARGET_USER" "$dest"
        rm -f "$blockfile"
    }

    install_shell_file ./zshrc .zshrc
    install_shell_file ./zprofile .zprofile
fi

echo ""
echo "\033[1;32mSetup complete.\033[0m"
