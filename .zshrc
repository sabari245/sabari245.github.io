skip_global_compinit=1

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_VERIFY
setopt HIST_EXPIRE_DUPS_FIRST

setopt INTERACTIVE_COMMENTS
setopt EXTENDED_GLOB
setopt GLOB_DOTS

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt PUSHD_MINUS

setopt PROMPT_SUBST

autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

bindkey -e

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search

bindkey '^H' backward-kill-word
bindkey '^W' backward-kill-word
bindkey '^[[3;5~' kill-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey "${terminfo[kcbt]}" reverse-menu-complete
bindkey "${terminfo[khome]}" beginning-of-line
bindkey "${terminfo[kend]}" end-of-line
bindkey "^[m" copy-prev-shell-word

zle_highlight=('paste:none')

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

autoload -U select-word-style
select-word-style bash
zstyle ':zle:*' word-chars '#'

autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats '(%b)'
precmd() { vcs_info }

PROMPT='%F{green}%n@%m%f:%F{cyan}%~%f ${vcs_info_msg_0_}%F{green}%#%f '

if [[ -f ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]]; then
  source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
  FAST_HIGHLIGHT_STYLES[comment]='fg=240'
fi

eval "$(zoxide init zsh --hook prompt)"
alias cd="z"

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias duh='du -sh -- * .*(N) | sort -h'
alias dur='du -h --max-depth=1 -- * .*(N) | sort -h'
alias dfh='df -h'
alias reload='source ~/.zshrc && echo "🔄 zsh config reloaded!"'
alias ls='eza --group-directories-first --icons=never'
alias lg='eza --group-directories-first --icons=never --git'
alias cc='claude --dangerously-skip-permissions'

activate() {
  source "${1:-.venv}/bin/activate"
}

zsh-setup() {
  local packages_pacman=(ripgrep zoxide eza fzf dua-cli)
  local packages_apt=(ripgrep zoxide eza fzf)

  if command -v pacman &>/dev/null; then
    echo "==> Arch detected, installing with pacman..."
    sudo pacman -S --needed --noconfirm "${packages_pacman[@]}"
  elif command -v apt &>/dev/null; then
    echo "==> Debian/Ubuntu detected, installing with apt..."
    sudo apt update && sudo apt install -y "${packages_apt[@]}"
    echo "==> Installing dua-cli via install script..."
    curl -LSfs https://raw.githubusercontent.com/Byron/dua-cli/master/ci/install.sh | \
      sh -s -- --git Byron/dua-cli --target x86_64-unknown-linux-musl --crate dua --tag v2.29.0
  else
    echo "Unsupported system: neither pacman nor apt found"
    return 1
  fi

  if [[ ! -d ~/.zsh/fast-syntax-highlighting ]]; then
    echo "==> Installing fast-syntax-highlighting..."
    mkdir -p ~/.zsh
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting ~/.zsh/fast-syntax-highlighting
  else
    echo "==> fast-syntax-highlighting already installed, pulling latest..."
    git -C ~/.zsh/fast-syntax-highlighting pull
  fi

  echo "==> Done! Run 'reload' to apply changes."
}

export GCM_CREDENTIAL_STORE=plaintext

[[ -f "$HOME/.local/share/../bin/env" ]] && source "$HOME/.local/share/../bin/env"

[[ -z "$CURSOR_AGENT" && -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
