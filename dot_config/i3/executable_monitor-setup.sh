#!/bin/bash
# Detect and enable all connected monitors dynamically
# Layout: external monitors left-to-right (first = primary), internal on far right

INTERNAL="eDP-1"

CONNECTED=$(xrandr --query | grep " connected" | cut -d' ' -f1)
EXTERNALS=()
for mon in $CONNECTED; do
    [[ "$mon" != "$INTERNAL" ]] && EXTERNALS+=("$mon")
done

echo "Connected: $CONNECTED"
echo "External: ${EXTERNALS[*]}"

CMD="xrandr"
PREV=""

if [[ ${#EXTERNALS[@]} -eq 0 ]]; then
    CMD+=" --output $INTERNAL --auto --primary"
else
    for mon in "${EXTERNALS[@]}"; do
        if [[ -z "$PREV" ]]; then
            CMD+=" --output $mon --auto --primary --pos 0x0"
        else
            CMD+=" --output $mon --auto --right-of $PREV"
        fi
        PREV="$mon"
    done
    CMD+=" --output $INTERNAL --auto --right-of $PREV"
fi

echo "Running: $CMD"
eval "$CMD"

# Restart polybar on all monitors
~/.config/polybar/launch.sh &

echo "Monitor setup complete"
