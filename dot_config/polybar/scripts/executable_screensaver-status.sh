#!/bin/bash
if xset q | grep -q "DPMS is Enabled"; then
    echo "󰌾"
else
    echo "%{F#9d0006}󰌿%{F-}"
fi
