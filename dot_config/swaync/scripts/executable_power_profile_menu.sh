#!/usr/bin/env bash
# Opens a small picker menu to choose a power profile, then applies it via
# power-profiles-daemon. Bound to the arrow half of the Power pill in swaync,
# the same way nm-connection-editor / blueman-manager are bound to the
# WiFi / Bluetooth arrows.

set -e

choice=$(printf "Performance\nBalanced\nPower Saver\n" | wofi --dmenu --prompt "Power Profile")

case "$choice" in
  "Performance")
    powerprofilesctl set performance
    ;;
  "Balanced")
    powerprofilesctl set balanced
    ;;
  "Power Saver")
    powerprofilesctl set power-saver
    ;;
  *)
    exit 0
    ;;
esac
