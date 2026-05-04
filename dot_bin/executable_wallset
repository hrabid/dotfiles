#!/usr/bin/env bash
# wallpaper.sh — Wallpaper picker → awww → matugen
# Keybind (Hyprland):
#   bind = $mod SHIFT, W, exec, ~/.config/rofi/scripts/wallpaper.sh

ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
CACHE_FILE="$HOME/.cache/current-wallpaper"

# Ensure cargo/local bins are in PATH (not always inherited from compositor)
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Guard: dir must exist
if [[ ! -d "$WALLPAPER_DIR" ]]; then
  notify-send "Wallpaper" "Directory not found:\n$WALLPAPER_DIR" --urgency=critical
  exit 1
fi

# Collect image files
mapfile -t WALLS < <(find "$WALLPAPER_DIR" \
  -maxdepth 2 -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" \
  -o -iname "*.png" -o -iname "*.webp" \) |
  sort)

if [[ ${#WALLS[@]} -eq 0 ]]; then
  notify-send "Wallpaper" "No images found in:\n$WALLPAPER_DIR" --urgency=normal
  exit 1
fi

# Show picker — feed filename + icon path per entry
CHOSEN=$(for w in "${WALLS[@]}"; do
  printf '%s\0icon\x1f%s\n' "$(basename "$w")" "$w"
done | rofi -dmenu \
  -show-icons \
  -theme "$ROFI_THEME" \
  -p "󰺵" \
  -no-custom)

[[ -z "$CHOSEN" ]] && exit 0

# Resolve full path
FULL_PATH=""
for w in "${WALLS[@]}"; do
  if [[ "$(basename "$w")" == "$CHOSEN" ]]; then
    FULL_PATH="$w"
    break
  fi
done

[[ -z "$FULL_PATH" ]] && exit 1

# Apply wallpaper
awww img "$FULL_PATH" \
  --transition-type wipe \
  --transition-angle 30 \
  --transition-duration 1.2 \
  --transition-fps 60

# Save for session restore
echo "$FULL_PATH" >"$CACHE_FILE"

# Run matugen synchronously so colors are ready before notification
if command -v matugen &>/dev/null; then
  notify-send "Wallpaper" "Generating colors…" \
    --urgency=low \
    --expire-time=2000

  matugen image "$FULL_PATH" --prefer=darkness

  notify-send "Wallpaper" "$(basename "$FULL_PATH")" \
    --icon="$FULL_PATH" \
    --urgency=low \
    --expire-time=3000
else
  notify-send "Wallpaper" "$(basename "$FULL_PATH")\n\nmatugen not found — colors not updated.\nInstall: cargo install matugen" \
    --icon="$FULL_PATH" \
    --urgency=normal \
    --expire-time=5000
fi
