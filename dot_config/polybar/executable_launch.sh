#!/bin/bash

# Send SIGTERM then SIGKILL to ensure polybar dies before screenchange-reload fires
killall -q polybar || true
sleep 0.3
killall -q -9 polybar 2>/dev/null || true

while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

rm -f /tmp/polybar-*.log

# Wait for xrandr to detect connected monitors (up to 10s)
for i in $(seq 1 20); do
    xrandr --query | grep -q " connected" && break
    sleep 0.5
done

# Wait until polybar detects at least one monitor (up to 10s)
for i in $(seq 1 20); do
    polybar --list-monitors 2>/dev/null | grep -q ':' && break
    sleep 0.5
done

PRIMARY=$(polybar --list-monitors | grep "(primary)" | cut -d":" -f1)
# If no primary is set, use the first monitor
[ -z "$PRIMARY" ] && PRIMARY=$(polybar --list-monitors | head -1 | cut -d":" -f1)

# Only spawn polybar for monitors that have an actual resolution (i.e. are enabled)
for m in $(polybar --list-monitors | grep ':' | cut -d":" -f1); do
    if [ "$m" = "$PRIMARY" ]; then
        MONITOR=$m polybar main-primary 2>&1 | tee -a /tmp/polybar-$m.log &
    else
        MONITOR=$m polybar main 2>&1 | tee -a /tmp/polybar-$m.log &
    fi
done
