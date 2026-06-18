# mac-setup

Automated macOS setup script for a fresh machine.

## What it does

- Installs Homebrew and packages (starship, git, gh, jq, ripgrep, fzf, awscli, tfenv, nvm, ghostty, and more)
- Installs casks (Ghostty, Obsidian, VS Code, Maccy, Stats, Tailscale, Scroll Reverser)
- Configures system preferences (Dock, Finder, keyboard, trackpad, menu bar, screenshots)
- Installs shell config (`~/.zshrc`, `~/.zprofile`)
- Installs Ghostty config and Starship prompt
- Enables Touch ID for `sudo`

## Usage

```sh
git clone git@github.com:ralphluaces/mac-setup.git
cd mac-setup
./setup.sh
```

You will be prompted to confirm before anything runs.

## Re-running

The script is idempotent and safe to re-run. Shell config files (`~/.zshrc`, `~/.zprofile`) use managed blocks:

```
# BEGIN mac-setup managed block
...
# END mac-setup managed block
```

Only the content inside the managed block is updated on re-run. Anything you add outside the block is left untouched.

## Files

| File | Description |
|------|-------------|
| `setup.sh` | Main setup script |
| `zshrc` | Shell config (managed block content) |
| `zprofile` | Login shell config (managed block content) |
| `starship.toml` | Starship prompt config |
| `ghostty.conf` | Ghostty terminal config |
| `aws-prompt.py` | AWS session status script used by the Starship prompt |

## Starship prompt

The prompt shows your active AWS profile, session validity, and time remaining:

- `aws:default ✓1h23m` — authenticated, time remaining
- `aws:prod ✗` — expired or no credentials found
- `aws:default:us-east-1 ✓45m` — with region when `AWS_REGION` is set
