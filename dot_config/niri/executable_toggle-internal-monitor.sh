#!/bin/sh
# Toggle the laptop's internal display (eDP-1) on/off.

state=$(niri msg --json outputs | jq -r '.["eDP-1"].logical')

if [ "$state" = "null" ]; then
    niri msg output eDP-1 on
else
    niri msg output eDP-1 off
fi
