#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════╗
# ║              scripts/emoji.sh                             ║
# ║  Emoji picker — rofimoji (preferred) / plain dmenu list   ║
# ╚═══════════════════════════════════════════════════════════╝
#
#  Install rofimoji:
#    pip install rofimoji     OR
#    pacman -S rofimoji
#
#  Keybinding example (Hyprland):
#    bind = $mod SHIFT, E, exec, ~/.config/rofi/scripts/emoji.sh

ROFI_THEME="$HOME/.config/rofi/emoji.rasi"

if command -v rofimoji &> /dev/null; then
  rofimoji \
    --action copy \
    --skin-tone neutral \
    --rofi-args "-theme $ROFI_THEME -p '󰱱  Emoji'"
else
  # Fallback: plain Unicode emoji list (bundled minimal set)
  EMOJI_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/rofi/emoji.txt"

  if [[ ! -f "$EMOJI_FILE" ]]; then
    mkdir -p "$(dirname "$EMOJI_FILE")"
    # Download Unicode emoji list on first run
    if command -v curl &> /dev/null; then
      curl -sL "https://unicode.org/Public/emoji/15.0/emoji-test.txt" \
        | grep "^[^#].*; fully-qualified" \
        | sed 's/.*# //' \
        | sed 's/ E[0-9.]*/\t/' \
        > "$EMOJI_FILE"
    fi
  fi

  if [[ -f "$EMOJI_FILE" ]]; then
    CHOSEN=$(rofi -dmenu \
                  -theme "$ROFI_THEME" \
                  -p "󰱱  Emoji" \
                  -matching fuzzy \
                  < "$EMOJI_FILE")

    EMOJI=$(echo "$CHOSEN" | cut -f1)

    if [[ -n "$EMOJI" ]]; then
      if command -v wl-copy &> /dev/null; then
        printf '%s' "$EMOJI" | wl-copy
      elif command -v xclip &> /dev/null; then
        printf '%s' "$EMOJI" | xclip -selection clipboard
      fi
      notify-send "Emoji copied" "$EMOJI" --urgency=low --expire-time=2000
    fi
  else
    notify-send "Emoji" "Install rofimoji for full emoji picker support." --urgency=normal
  fi
fi
