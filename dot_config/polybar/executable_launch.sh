#!/bin/bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

rm -f /tmp/polybar-*.log

sleep 2
PRIMARY=$(polybar --list-monitors | grep "(primary)" | cut -d":" -f1)
# If no primary is set, use the first monitor
[ -z "$PRIMARY" ] && PRIMARY=$(polybar --list-monitors | head -1 | cut -d":" -f1)

for m in $(polybar --list-monitors | cut -d":" -f1); do
    if [ "$m" = "$PRIMARY" ]; then
        MONITOR=$m polybar main-primary 2>&1 | tee -a /tmp/polybar-$m.log &
    else
        MONITOR=$m polybar main 2>&1 | tee -a /tmp/polybar-$m.log &
    fi
done
