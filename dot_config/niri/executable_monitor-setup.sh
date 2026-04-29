#!/bin/bash
# Detect and enable all connected outputs dynamically.
# Layout: external monitors left-to-right (first = primary-most), eDP-1 on the far right.

set -euo pipefail

INTERNAL="eDP-1"

OUTPUTS_JSON=$(niri msg --json outputs)

mapfile -t CONNECTED < <(echo "$OUTPUTS_JSON" | jq -r 'keys[]')

EXTERNALS=()
HAS_INTERNAL=false
for o in "${CONNECTED[@]}"; do
    if [[ "$o" == "$INTERNAL" ]]; then
        HAS_INTERNAL=true
    else
        EXTERNALS+=("$o")
    fi
done

echo "Connected: ${CONNECTED[*]}"
echo "External:  ${EXTERNALS[*]:-none}"

# Logical width = preferred mode width / scale.
# Default scale = current scale if output is on, else 1.0.
logical_width() {
    local name="$1"
    echo "$OUTPUTS_JSON" | jq -r --arg n "$name" '
        .[$n] as $o
        | ($o.modes | map(select(.is_preferred)) | .[0].width) as $w
        | ($o.logical.scale // 1.0) as $s
        | ($w / $s | floor)
    '
}

place() {
    local name="$1" x="$2"
    echo "  $name -> on, position ${x}x0"
    niri msg output "$name" on
    niri msg output "$name" mode auto
    niri msg output "$name" position --x "$x" --y 0
}

x_offset=0

if (( ${#EXTERNALS[@]} == 0 )); then
    if $HAS_INTERNAL; then
        place "$INTERNAL" 0
    else
        echo "No outputs detected." >&2
        exit 1
    fi
else
    for m in "${EXTERNALS[@]}"; do
        place "$m" "$x_offset"
        w=$(logical_width "$m")
        x_offset=$(( x_offset + w ))
    done
    if $HAS_INTERNAL; then
        place "$INTERNAL" "$x_offset"
    fi
fi

# Disable any output not in the connected set is implicit — niri only manages
# outputs it sees. Nothing else to do.

echo "Monitor setup complete."
