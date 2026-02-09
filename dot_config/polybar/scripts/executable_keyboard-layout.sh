#!/bin/bash

# Get current layout using xkb-switch if available, otherwise parse xset
if command -v xkb-switch &> /dev/null; then
    layout=$(xkb-switch -p)
elif command -v xkblayout-state &> /dev/null; then
    layout=$(xkblayout-state print %s)
else
    # Fallback: check LED mask from xset
    led=$(xset -q | grep "LED mask" | awk '{print $NF}')
    group2=$((16#${led} & 0x1000))

    layouts=$(setxkbmap -query | grep layout | awk '{print $2}')
    first=$(echo "$layouts" | cut -d',' -f1)
    second=$(echo "$layouts" | cut -d',' -f2)

    if [[ $group2 -ne 0 ]] && [[ -n "$second" ]]; then
        layout="$second"
    else
        layout="$first"
    fi
fi

case $layout in
    us) echo "󰌌 US" ;;
    ee) echo "󰌌 EE" ;;
    *)  echo "󰌌 $layout" ;;
esac
