#!/bin/bash

# Send SIGTERM then SIGKILL to ensure polybar dies before screenchange-reload fires
killall -q polybar
sleep 0.3
killall -q -9 polybar 2>/dev/null

while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

rm -f /tmp/polybar-*.log

# Wait until polybar detects at least one monitor (up to 10s)
for i in $(seq 1 20); do
    polybar --list-monitors 2>/dev/null | grep -q ':' && break
    sleep 0.5
done

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
