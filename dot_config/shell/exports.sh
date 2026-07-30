# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Default editors
export EDITOR="nvim"
export VISUAL="nvim"

# PATH
export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/.local/bin/:$PATH"
export PATH="$HOME/.cargo/bin/:$PATH"
export PATH=${PATH}:$(go env GOPATH)/bin

if [[ -d "$HOME/.iximiuz/labctl/bin" ]]; then
  export PATH="$HOME/.iximiuz/labctl/bin:$PATH"
else
  :
fi

# fzf exports
# Preview file content using bat (https://github.com/sharkdp/bat)
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview '
    if [ -d {} ]; then
      tree -C {} | head -200
    else
      bat --style=numbers --color=always {} 2>/dev/null || cat {}
    fi
  '
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
"

# Print tree structure in the preview window
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

# Changing default for man page to nvim
set -o vi
export MANPAGER='nvim +Man!'
