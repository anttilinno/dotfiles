#!/bin/bash
# Toggle internal monitor on/off

INTERNAL="eDP-1"
MON_4K="DP-1-1.2"
MON_1080="DP-1-1.3"

# Check if internal monitor is currently active (has a resolution set)
if xrandr | grep "^$INTERNAL" | grep -q "+[0-9]"; then
    # Internal is on, turn it off
    echo "Disabling internal monitor"
    xrandr --output "$INTERNAL" --off
else
    # Internal is off, turn it on
    echo "Enabling internal monitor"

    # Check which external monitors are connected and position internal to the right
    CONNECTED=$(xrandr --query | grep " connected" | cut -d' ' -f1)

    if echo "$CONNECTED" | grep -q "$MON_1080"; then
        xrandr --output "$INTERNAL" --auto --right-of "$MON_1080"
    elif echo "$CONNECTED" | grep -q "$MON_4K"; then
        xrandr --output "$INTERNAL" --auto --right-of "$MON_4K"
    else
        xrandr --output "$INTERNAL" --auto --primary
    fi
fi

# Restart polybar
~/.config/polybar/launch.sh &
