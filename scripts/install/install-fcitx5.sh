# Core fcitx5 stack
sudo pacman -S fcitx5 fcitx5-qt fcitx5-gtk fcitx5-configtool

# OpenBangla for Avro phonetic (AUR)
paru -S openbangla-keyboard fcitx5-openbangla
# or if you hit the version-pinning dep issue:
paru -S openbangla-keyboard-git fcitx5-openbangla-git
