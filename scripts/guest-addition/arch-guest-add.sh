#!/bin/bash
# Install VirtualBox Guest Additions on Arch Linux/Manjaro

set -e

echo "Updating system packages..."
sudo pacman -Syu --noconfirm

echo "Installing required packages..."
sudo pacman -S --noconfirm virtualbox-guest-utils

echo "Loading VirtualBox Guest Modules..."
sudo systemctl enable vboxservice --now

echo "Reboot your system to apply changes."

