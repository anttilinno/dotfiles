#!/bin/bash

powered=$(busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null | grep -q "true" && echo yes)

if [[ -z "$powered" ]]; then
    echo "%{F#9d0006}󰂲%{F-}"
    exit 0
fi

connected=false
for dev in $(busctl tree org.bluez 2>/dev/null | grep -o '/org/bluez/hci0/dev_[^ ]*'); do
    if busctl get-property org.bluez "$dev" org.bluez.Device1 Connected 2>/dev/null | grep -q "true"; then
        connected=true
        break
    fi
done

if [[ "$connected" == "true" ]]; then
    echo "%{F#427b58}󰂱%{F-}"
else
    echo "󰂯"
fi
