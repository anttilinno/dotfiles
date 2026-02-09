#!/bin/bash

powered=$(bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && echo yes)

if [[ -z "$powered" ]]; then
    echo "%{F#9d0006}󰂲%{F-}"
    exit 0
fi

connected=$(bluetoothctl devices Connected 2>/dev/null | head -1)

if [[ -n "$connected" ]]; then
    echo "%{F#427b58}󰂱%{F-}"
else
    echo "󰂯"
fi
