# Rofi Material You Themes — Setup Guide

---

## 1. Install rofi

```bash
# Arch / Hyprland (use wayland fork)
sudo pacman -S rofi-wayland

# Debian / Ubuntu
sudo apt install rofi
```

> **Important:** If you're on Wayland (Hyprland, Sway) always use `rofi-wayland`, not plain `rofi`. Plain rofi will not render on Wayland.

---

## 2. Install fonts and icons

```bash
# Arch
sudo pacman -S ttf-jetbrains-mono-nerd noto-fonts-emoji papirus-icon-theme

# Debian / Ubuntu
sudo apt install fonts-nerd-fonts-jetbrains-mono fonts-noto-color-emoji papirus-icon-theme
```

After installing fonts run:
```bash
fc-cache -fv
```

Verify the font name rofi will see:
```bash
fc-list | grep -i "JetBrains"
# Should show: JetBrainsMono Nerd Font
```

If the font name differs on your system, open `shared.rasi` and change this line:
```
font: "JetBrainsMono Nerd Font 11";
```

---

## 3. Copy theme files

```bash
# Create config dir if it doesn't exist
mkdir -p ~/.config/rofi/scripts

# Copy everything
cp *.rasi ~/.config/rofi/
cp scripts/*.sh ~/.config/rofi/scripts/
chmod +x ~/.config/rofi/scripts/*.sh
```

Your `~/.config/rofi/` should look like:
```
~/.config/rofi/
├── colors.rasi
├── shared.rasi
├── launcher.rasi
├── runner.rasi
├── window.rasi
├── clipboard.rasi
├── powermenu.rasi
├── wallpaper.rasi
├── screenshot.rasi
├── emoji.rasi
├── ssh.rasi
└── scripts/
    ├── wallpaper.sh
    ├── clipboard.sh
    ├── powermenu.sh
    ├── screenshot.sh
    └── emoji.sh
```

---

## 4. Verify theme syntax

```bash
for f in ~/.config/rofi/*.rasi; do
  result=$(rofi -rasi-validate "$f" 2>&1)
  [[ -n "$result" ]] && echo "FAIL: $f" && echo "$result" || echo "OK: $f"
done
```

All should print `OK`.

---

## 5. Test each theme manually

```bash
# App launcher
rofi -show drun -theme ~/.config/rofi/launcher.rasi

# Window switcher
rofi -show window -theme ~/.config/rofi/window.rasi

# Command runner
rofi -show run -theme ~/.config/rofi/runner.rasi

# SSH picker
rofi -show ssh -theme ~/.config/rofi/ssh.rasi

# Clipboard (needs cliphist)
cliphist list | rofi -dmenu -theme ~/.config/rofi/clipboard.rasi

# Power menu
~/.config/rofi/scripts/powermenu.sh

# Wallpaper picker (needs swww running)
~/.config/rofi/scripts/wallpaper.sh

# Screenshot picker
~/.config/rofi/scripts/screenshot.sh
```

---

## 6. Clipboard (cliphist)

Install:
```bash
sudo pacman -S cliphist wl-clipboard   # Arch
```

Add to Hyprland config (`~/.config/hypr/hyprland.conf`):
```ini
exec-once = wl-paste --type text  --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

Then log out and back in (or run those two commands manually in a terminal). After copying something, test:
```bash
cliphist list
```

You should see entries. Now the clipboard script will work.

---

## 7. Wallpaper switcher (swww)

Install:
```bash
sudo pacman -S swww
```

Start the daemon (add to Hyprland config):
```ini
exec-once = swww-daemon
```

Set your wallpaper directory:
```bash
mkdir -p ~/Pictures/Wallpapers
# copy some wallpapers in there
```

Run the picker:
```bash
~/.config/rofi/scripts/wallpaper.sh
```

To use a different directory:
```bash
WALLPAPER_DIR=~/wallpapers ~/.config/rofi/scripts/wallpaper.sh
```

---

## 8. Matugen integration

Install matugen:
```bash
# Arch AUR
yay -S matugen-bin

# Cargo
cargo install matugen
```

Your template is already at `~/.config/matugen/templates/rofi-colors.rasi`.

Add this to `~/.config/matugen/config.toml`:
```toml
[[config.templates]]
input_path  = "~/.config/matugen/templates/rofi-colors.rasi"
output_path = "~/.config/rofi/colors.rasi"
```

Test it:
```bash
matugen image ~/Pictures/Wallpapers/your-wallpaper.jpg
```

Check that `~/.config/rofi/colors.rasi` got updated with new hex values. The wallpaper script calls this automatically on every wallpaper change.

---

## 9. Keybindings (Hyprland)

Add to `~/.config/hypr/keybinds.conf` or inside `hyprland.conf`:

```ini
$mod = SUPER

bind = $mod,       Space,    exec, rofi -show drun   -theme ~/.config/rofi/launcher.rasi
bind = $mod,       Tab,      exec, rofi -show window -theme ~/.config/rofi/window.rasi
bind = $mod SHIFT, Space,    exec, rofi -show run    -theme ~/.config/rofi/runner.rasi
bind = $mod,       S,        exec, rofi -show ssh    -theme ~/.config/rofi/ssh.rasi
bind = $mod,       V,        exec, ~/.config/rofi/scripts/clipboard.sh
bind = $mod,       Escape,   exec, ~/.config/rofi/scripts/powermenu.sh
bind = $mod SHIFT, W,        exec, ~/.config/rofi/scripts/wallpaper.sh
bind = ,           Print,    exec, ~/.config/rofi/scripts/screenshot.sh
bind = $mod SHIFT, E,        exec, ~/.config/rofi/scripts/emoji.sh
```

---

## 10. Blur (optional, Hyprland)

Add to `~/.config/hypr/hyprland.conf`:

```ini
layerrule = blur, rofi
layerrule = ignorezero, rofi
```

---

## Common errors

**`Failed to open display`**
You ran rofi from a terminal outside a graphical session. Just open a terminal inside your desktop and run it there, or use the keybinding.

**`parse error` / `syntax error`**
Run the validator to find which file and line:
```bash
rofi -rasi-validate ~/.config/rofi/launcher.rasi
```

**Icons not showing**
Make sure Papirus is installed and the icon theme name matches exactly:
```bash
ls /usr/share/icons/ | grep -i papirus
```
If the folder is named `Papirus-Dark`, the config is correct. If different, edit the `icon-theme:` line in each `.rasi` file.

**Clipboard shows nothing**
`cliphist` only stores entries after it's been running. Copy something, then open the picker again.

**Wallpaper script: `swww` not found**
Start the daemon first: `swww-daemon &`, then run the script.

**Wallpaper script: no images found**
Check your `WALLPAPER_DIR`. Default is `~/Pictures/Wallpapers`. Make sure images are `.jpg`, `.jpeg`, `.png`, or `.webp`.
