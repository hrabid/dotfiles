#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════╗
# ║            scripts/clipboard.sh                           ║
# ║  Clipboard history — cliphist (Wayland) / xclip (X11)    ║
# ╚═══════════════════════════════════════════════════════════╝
#
#  Wayland (recommended):
#    pacman -S cliphist wl-clipboard
#    # Add to Hyprland config:
#    exec-once = wl-paste --type text  --watch cliphist store
#    exec-once = wl-paste --type image --watch cliphist store
#
#  X11 fallback: xclip + greenclip
#
#  Keybinding example (Hyprland):
#    bind = $mod, V, exec, ~/.config/rofi/scripts/clipboard.sh

ROFI_THEME="$HOME/.config/rofi/clipboard.rasi"

if command -v cliphist &> /dev/null && command -v wl-copy &> /dev/null; then
  # ── Wayland: cliphist ────────────────────────────────────────
  cliphist list \
    | rofi -dmenu \
           -theme "$ROFI_THEME" \
           -p "󰅎  Clipboard" \
           -display-columns 2 \
    | cliphist decode \
    | wl-copy

elif command -v greenclip &> /dev/null; then
  # ── Greenclip fallback ───────────────────────────────────────
  rofi -modi "clipboard:greenclip print" \
       -show clipboard \
       -theme "$ROFI_THEME" \
       -run-command '{cmd}'

elif command -v xclip &> /dev/null; then
  # ── Minimal xclip fallback ───────────────────────────────────
  # Requires xclip-rofi-wrapper or a custom history file
  echo "[clipboard.sh] Install cliphist for full clipboard history support." >&2
  exit 1

else
  notify-send "Clipboard" "No clipboard manager found.\nInstall cliphist (Wayland) or greenclip (X11)." \
    --icon=edit-paste \
    --urgency=normal
fi
