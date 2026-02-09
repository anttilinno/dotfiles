#!/bin/bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

rm -f /tmp/polybar-*.log

for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar main 2>&1 | tee -a /tmp/polybar-$m.log &
done
