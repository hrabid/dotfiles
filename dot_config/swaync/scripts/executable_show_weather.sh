#!/usr/bin/env bash
# ~/.config/swaync/scripts/show_weather.sh
weather=$(curl -s 'wttr.in/?format=%C+%t')
notify-send "Weather" "$weather"
