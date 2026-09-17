# installation for minimal command line interface

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/hrabid/dotfiles.git
```

Source your `~/bashrc`

```bash
source ~/.bashrc
```

Run the Installation script for dependencies.
For `dnf` based systems:

```bash
dnf-install-dotfiles
```

For `apt` based systems:

```bash
apt-install-dotfiles
```

For `pacman` based systems:

```bash
pacman-install-dotfiles
```

# installation for graphical desktop

```bash
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprsunset waybar rofi-wayland swaync hyprpicker swayosd \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-kde-agent brightnessctl \
  pipewire pipewire-pulse bluez blueman nm-connection-editor power-profiles-daemon playerctl pavucontrol \
  qt5ct qt6ct kvantum matugen awww \
  adw-gtk-theme dconf gsettings-desktop-schemas nwg-look \
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd \
  alacritty tree dolphin \
  openssh unrar p7zip \
  cliphist wl-clipboard wl-clip-persist \
  github-cli chezmoi hugo python go \
  tldr man-db \
  fcitx5 fcitx5-qt fcitx5-gtk fcitx5-configtool \
  obsidian celluloid elisa flameshot wireshark-qt telegram-desktop bitwarden
```

install `am` -- application manager for appimage

```bash
wget -q https://raw.githubusercontent.com/ivan-hc/AM/main/AM-INSTALLER && chmod a+x ./AM-INSTALLER && ./AM-INSTALLER && rm ./AM-INSTALLER

```

install appimage applications

```bash
am -i fluent-reader notesnook superproductivity vidbee
```

install packages from aur

```bash
paru -S --needed \
  hyprmod waybar-git wlogout \
  bibata-cursor-theme darkly-bin breeze breeze5 breeze-gtk breeze-icons qt5ct-kde qt6ct-kde \
  brave-bin vesktop-bin onlyoffice-bin sigma-file-manager-bin leaf-markdown-viewer-bin localsend-bin \
  shelly-bin snappy-switcher tldx-bin
```

# boot screen configuration

See: https://vopslabs.com/blog/linux-plymouth-boot-screen/
