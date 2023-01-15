export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth

export GREP_OPTIONS='--color=auto'

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
alias gcmp="git checkout master&&git pull"
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

# Helpful terraform alias
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

eval "$(starship init zsh)"