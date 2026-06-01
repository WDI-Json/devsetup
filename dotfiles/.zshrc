export LANG="en_US.UTF-8"

[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/catppuccin.omp.json)"
eval "$(zoxide init --cmd cd zsh)"

export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

# helm-utils
export HELM_UTILS_HOME="$HOME/GITHUB/helm-utils"
export PATH="$PATH:$HELM_UTILS_HOME"

# Rancher Desktop
export PATH="$HOME/.rd/bin:$PATH"

# Aliases
alias hosts="bat /etc/hosts"
alias sshconfig="bat ~/.ssh/config"

# Kubectl
alias k=kubectl
alias kapi="kubectl api-resources"
alias kg="kubectl get"
alias ke="kubectl explain"
alias kd="kubectl delete"
alias kc="kubectl create"
alias kr="kubectl run"
alias kf="kubectl config"
alias kn="kubectl config set-context --current --namespace"

export do="--dry-run=client"
export oy="-o=yaml"
export ow="-o=wide"
export re="--restart=Never"

# Yazi: change cwd on exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# Docker CLI completions
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit

[[ $commands[kubectl] ]] && source <(kubectl completion zsh)
