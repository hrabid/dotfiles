#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════╗
# ║            scripts/screenshot.sh                         ║
# ║  Screenshot mode picker — grimblast / grim+slurp (Wayland)║
# ║  Also supports scrot / maim (X11)                        ║
# ╚═══════════════════════════════════════════════════════════╝
#
#  Keybinding example (Hyprland):
#    bind = ,      Print,    exec, ~/.config/rofi/scripts/screenshot.sh
#    bind = SHIFT, Print,    exec, grimblast copy area   # quick selection

ROFI_THEME="$HOME/.config/rofi/screenshot.rasi"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="screenshot_$DATE.png"
FULL_PATH="$SCREENSHOT_DIR/$FILENAME"

mkdir -p "$SCREENSHOT_DIR"

# ── Items ────────────────────────────────────────────────────────
FULLSCREEN="󰹑  Full screen"
SELECTION="󰩬  Selection"
WINDOW="󱃻  Active window"
CLIPBOARD="󱐋  Clipboard only"
DELAYED="  Delayed 3s"

CHOSEN=$(printf '%s\n' \
  "$FULLSCREEN" \
  "$SELECTION" \
  "$WINDOW" \
  "$CLIPBOARD" \
  "$DELAYED" |
  rofi -dmenu \
    -theme "$ROFI_THEME" \
    -p "󰹑 Screenshot" \
    -no-custom)

[[ -z "$CHOSEN" ]] && exit 0

# ── Helper: notify with preview ──────────────────────────────────
notify_screenshot() {
  local file="$1"
  notify-send "Screenshot saved" "$(basename "$file")" \
    --icon="$file" \
    --urgency=low \
    --expire-time=4000
}

# ── Dispatch ──────────────────────────────────────────────────────
if command -v grimblast &>/dev/null; then
  # ── grimblast (Hyprland-optimised) ─────────────────────────
  case "$CHOSEN" in
  "$FULLSCREEN")
    grimblast copysave screen "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  "$SELECTION")
    grimblast copysave area "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  "$WINDOW")
    grimblast copysave active "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  "$CLIPBOARD")
    grimblast copy area
    notify-send "Screenshot" "Copied to clipboard" --urgency=low
    ;;
  "$DELAYED")
    sleep 3
    grimblast copysave screen "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  esac

elif command -v grim &>/dev/null; then
  # ── grim + slurp ────────────────────────────────────────────
  case "$CHOSEN" in
  "$FULLSCREEN")
    grim "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  "$SELECTION")
    grim -g "$(slurp)" "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  "$WINDOW")
    # Get focused window geometry via hyprctl / swaymsg
    if command -v hyprctl &>/dev/null; then
      GEOM=$(hyprctl activewindow -j |
        python3 -c "import sys,json; d=json.load(sys.stdin); \
            at=d['at']; sz=d['size']; \
            print(f'{at[0]},{at[1]} {sz[0]}x{sz[1]}')")
      grim -g "$GEOM" "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    else
      grim "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    fi
    ;;
  "$CLIPBOARD")
    grim -g "$(slurp)" - | wl-copy
    notify-send "Screenshot" "Copied to clipboard" --urgency=low
    ;;
  "$DELAYED")
    sleep 3
    grim "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  esac

elif command -v scrot &>/dev/null; then
  # ── scrot (X11 fallback) ─────────────────────────────────────
  case "$CHOSEN" in
  "$FULLSCREEN") scrot "$FULL_PATH" && notify_screenshot "$FULL_PATH" ;;
  "$SELECTION") scrot -s "$FULL_PATH" && notify_screenshot "$FULL_PATH" ;;
  "$WINDOW") scrot -u "$FULL_PATH" && notify_screenshot "$FULL_PATH" ;;
  "$CLIPBOARD") scrot -s /tmp/tmp_screenshot.png && xclip -selection clipboard -t image/png </tmp/tmp_screenshot.png ;;
  "$DELAYED")
    sleep 3
    scrot "$FULL_PATH" && notify_screenshot "$FULL_PATH"
    ;;
  esac

else
  notify-send "Screenshot" "No screenshot tool found.\nInstall grimblast or grim." --urgency=critical
fi
