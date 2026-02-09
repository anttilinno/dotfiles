#!/bin/bash

eth_connected=$(cat /sys/class/net/e*/carrier 2>/dev/null | grep -q 1 && echo yes)
wifi_connected=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -q '^yes' && echo yes)

if [[ -n "$wifi_connected" ]]; then
    echo "%{F#427b58}󰤨%{F-}"
elif [[ -n "$eth_connected" ]]; then
    echo "%{F#427b58}󰈀%{F-}"
else
    echo "%{F#9d0006}󰤭%{F-}"
fi
