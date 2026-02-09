#!/bin/bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

primary=$(polybar --list-monitors | grep '(primary)' | cut -d: -f1)

for m in $(polybar --list-monitors | cut -d":" -f1); do
    tray=none
    [[ "$m" == "$primary" ]] && tray=right
    MONITOR=$m TRAY_POSITION=$tray polybar main &
done
