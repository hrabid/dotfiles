# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# paths
export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/.local/bin/:$PATH"
export PATH="$HOME/.cargo/bin/:$PATH"

if command -v go >/dev/null 2>&1; then
  export PATH=${PATH}:$(go env GOPATH)/bin
fi

if [[ -d "$HOME/.iximiuz/labctl/bin" ]]; then
  export PATH="$HOME/.iximiuz/labctl/bin:$PATH"
else
  :
fi
