export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth

export GREP_OPTIONS='--color=auto'

# Only regenerate compinit cache once per day
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit -u
else
  compinit -uC
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
setopt AUTO_LIST
setopt NO_AUTO_MENU

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

alias p='ping'
alias v='view'
alias sv='sudo view'
alias svim='sudo vim'

alias l='ls -hl -G'
alias ls='ls -G'
alias ll='ls -AhlG'
alias la='ls -ahlG'

alias lower="tr '[:upper:]' '[:lower:]'"
alias upper="tr '[:lower:]' '[:upper:]'"

alias rmpyc='find . -type f -name "*.pyc" -exec rm -f {} \;; find . -type d -name "__pycache__" -exec rm -rf {} \;'
alias listen='netstat -tulnp | grep -i LISTEN'

# Helpful git aliases
alias gl="git log --pretty=fuller"
alias gitlog="git log --pretty=fuller"
alias gcm="git checkout master"
alias gcmp="git checkout main&&git pull"
alias cdgr="cd __GIT_DIR__"
alias cdgd="cd __GIT_DIR__"
alias gp="git pull"
alias gn="git checkout -b"
alias grm="git rebase master"
alias grom="git rebase origin/master"
alias gc="git commit -a"
alias ga="git add ."
alias gg="git grep"
alias gs="git status"
alias gd="git diff"
alias gds="git diff --staged"
alias show="git show"
alias checkout="git checkout"
alias amend="git commit -a --amend"
alias gpu='git push --set-upstream origin `git branch --show-current`'
function gbd {
    cd $(git rev-parse --show-toplevel)
}

# Helpful terraform aliases
alias ti="terraform init"
alias tp="terraform plan"
alias tws="terraform workspace select"
alias tfmt="terraform fmt"

# Helpful tmux aliases
alias ta="tmux attach"
alias tas="tmux attach-session -t"
alias tls="tmux ls"
alias tks="tmux kill-session -t"

# kubectl aliases
alias k="kubectl"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kc="kubectx"

export NVM_DIR="$HOME/.nvm"
# Lazy-load nvm — only load when nvm/node/npm is first called
nvm() { unfunction nvm node npm npx; [ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"; nvm "$@"; }
node() { unfunction nvm node npm npx; [ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"; node "$@"; }
npm() { unfunction nvm node npm npx; [ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"; npm "$@"; }
npx() { unfunction nvm node npm npx; [ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"; npx "$@"; }

export PATH="$HOME/.local/bin:$PATH"

ssh-add -l &>/dev/null || ssh-add --apple-use-keychain 2>/dev/null

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

eval "$(starship init zsh)"
