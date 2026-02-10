#!/bin/bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

rm -f /tmp/polybar-*.log

PRIMARY=$(polybar --list-monitors | grep "(primary)" | cut -d":" -f1)

for m in $(polybar --list-monitors | cut -d":" -f1); do
    if [ "$m" = "$PRIMARY" ]; then
        MONITOR=$m polybar main-primary 2>&1 | tee -a /tmp/polybar-$m.log &
    else
        MONITOR=$m polybar main 2>&1 | tee -a /tmp/polybar-$m.log &
    fi
done
