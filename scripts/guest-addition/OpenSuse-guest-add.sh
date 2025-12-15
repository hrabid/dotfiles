#!/bin/bash
# Install VirtualBox Guest Additions on OpenSUSE

set -e

echo "Updating system packages..."
sudo zypper refresh
sudo zypper update -y

echo "Installing required packages..."
sudo zypper install -y gcc make perl kernel-default-devel dkms

echo "Mounting Guest Additions CD..."
sudo mkdir -p /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom || sudo mount /dev/sr0 /mnt/cdrom

echo "Running the installer..."
sudo /mnt/cdrom/VBoxLinuxAdditions.run

echo "Cleaning up..."
sudo umount /mnt/cdrom
sudo rmdir /mnt/cdrom

echo "Reboot your system to apply changes."

