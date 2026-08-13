# Default editors
export EDITOR="nvim"
export VISUAL="nvim"

# Changing default for man page to nvim
set -o vi
export MANPAGER='nvim +Man!'

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
