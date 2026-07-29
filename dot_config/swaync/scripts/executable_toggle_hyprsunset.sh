#!/usr/bin/env bash
set +e # disable immediate exit on error

if [[ "$SWAYNC_TOGGLE_STATE" == true ]]; then
  systemctl --user start hyprsunset.service >/dev/null 2>&1
  if systemctl --user is-active --quiet hyprsunset.service; then
    notify-send -u low -t 1500 -i weather-clear-night "Night Light" "Enabled"
  else
    notify-send -u critical "Night Light" "Failed to start — check journalctl --user -u hyprsunset"
  fi
else
  systemctl --user stop hyprsunset.service >/dev/null 2>&1
  notify-send -u low -t 1500 -i weather-clear-night "Night Light" "Disabled"
fi

exit 0
