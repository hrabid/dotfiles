#!/bin/bash
# Install VirtualBox Guest Additions on Ubuntu/Debian

set -e

echo "Updating package list..."
sudo apt update

echo "Installing required packages..."
sudo apt install -y build-essential dkms linux-headers-$(uname -r)

echo "Mounting Guest Additions CD..."
sudo mkdir -p /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom || sudo mount /dev/sr0 /mnt/cdrom

echo "Running the installer..."
sudo /mnt/cdrom/VBoxLinuxAdditions.run

echo "Cleaning up..."
sudo umount /mnt/cdrom
sudo rmdir /mnt/cdrom

echo "Reboot your system to apply changes."


