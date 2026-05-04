#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════╗
# ║              scripts/powermenu.sh                         ║
# ║  Power / session menu — calls appropriate system command  ║
# ╚═══════════════════════════════════════════════════════════╝
#
#  Requires one of:
#    systemctl  (systemd — shutdown/reboot/suspend/hibernate)
#    loginctl   (logind  — lock/logout)
#    swaylock / hyprlock  (screen lock)
#
#  Keybinding example (Hyprland):
#    bind = $mod, Escape, exec, ~/.config/rofi/scripts/powermenu.sh

ROFI_THEME="$HOME/.config/rofi/powermenu.rasi"

# ── Actions ──────────────────────────────────────────────────────
#  Using Nerd Font + label two-line approach:
#  Each option is rendered as "ICON\nLABEL" but since Rofi dmenu
#  shows it on one line we format as "ICON  LABEL"
SHUTDOWN="󰐥  Shutdown"
REBOOT="󰜉  Reboot"
SUSPEND="󰒲  Suspend"
HIBERNATE="󱠙  Hibernate"
LOGOUT="󰍃  Logout"
LOCK="󰌾  Lock"

# ── Prompt Rofi ──────────────────────────────────────────────────
CHOSEN=$(printf '%s\n' \
    "$SHUTDOWN" \
    "$REBOOT" \
    "$SUSPEND" \
    "$HIBERNATE" \
    "$LOGOUT" \
    "$LOCK" \
  | rofi -dmenu \
         -theme "$ROFI_THEME" \
         -p "Session" \
         -selected-row 5 \
         -no-custom)

# ── Execute ───────────────────────────────────────────────────────
case "$CHOSEN" in
  "$SHUTDOWN")
    systemctl poweroff
    ;;
  "$REBOOT")
    systemctl reboot
    ;;
  "$SUSPEND")
    systemctl suspend
    ;;
  "$HIBERNATE")
    systemctl hibernate
    ;;
  "$LOGOUT")
    # Detect compositor
    if pgrep -x "hyprland" > /dev/null; then
      hyprctl dispatch exit
    elif pgrep -x "sway" > /dev/null; then
      swaymsg exit
    elif pgrep -x "bspwm" > /dev/null; then
      pkill -x bspwm
    else
      loginctl terminate-session "$XDG_SESSION_ID"
    fi
    ;;
  "$LOCK")
    # Prefer hyprlock → swaylock → i3lock
    if command -v hyprlock &> /dev/null; then
      hyprlock
    elif command -v swaylock &> /dev/null; then
      swaylock -f
    elif command -v i3lock &> /dev/null; then
      i3lock -c 141218
    fi
    ;;
esac
