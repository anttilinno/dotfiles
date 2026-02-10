#!/bin/bash
# Interactive monitor arrangement wizard with presets

set -euo pipefail

# --- Presets ---
# Format: name|mon1:pos,mon2:pos,...|primary|off_monitors
# pos: left-to-right order (1,2,3...), alignment is always bottom
# off_monitors: monitors to disable (comma-separated, use "INTERNAL" for eDP-1)
PRESETS=(
    "work|DP-1-1.2:1,DP-1-1.3:2|DP-1-1.2|eDP-1"
)

# Gather connected monitors and their preferred resolutions
declare -a MONITORS=()
declare -A PREFERRED_RES=()
declare -A ALL_RES=()

while IFS= read -r line; do
    if [[ "$line" =~ ^([a-zA-Z0-9._-]+)\ connected ]]; then
        current="${BASH_REMATCH[1]}"
        MONITORS+=("$current")
        ALL_RES[$current]=""
    elif [[ -n "${current:-}" && "$line" =~ ^[[:space:]]+([0-9]+x[0-9]+) ]]; then
        res="${BASH_REMATCH[1]}"
        ALL_RES[$current]+="$res "
        if [[ "$line" == *"+"* && -z "${PREFERRED_RES[$current]:-}" ]]; then
            PREFERRED_RES[$current]="$res"
        fi
    fi
done < <(xrandr --query)

if (( ${#MONITORS[@]} == 0 )); then
    echo "No connected monitors found."
    exit 1
fi

# --- Check which presets are available ---
is_connected() {
    for m in "${MONITORS[@]}"; do
        [[ "$m" == "$1" ]] && return 0
    done
    return 1
}

declare -a AVAILABLE_PRESETS=()
for preset in "${PRESETS[@]}"; do
    IFS='|' read -r pname pmons _ poff <<< "$preset"
    all_present=true
    # Check enabled monitors are connected
    IFS=',' read -ra entries <<< "$pmons"
    for entry in "${entries[@]}"; do
        mon="${entry%%:*}"
        is_connected "$mon" || { all_present=false; break; }
    done
    # Check off monitors are connected (so we can turn them off)
    if $all_present && [[ -n "$poff" ]]; then
        IFS=',' read -ra off_mons <<< "$poff"
        for om in "${off_mons[@]}"; do
            is_connected "$om" || { all_present=false; break; }
        done
    fi
    $all_present && AVAILABLE_PRESETS+=("$preset")
done

apply_preset() {
    local preset="$1"
    IFS='|' read -r pname pmons pprimary poff <<< "$preset"

    # Parse monitors and sort by position
    declare -a ordered_mons=()
    IFS=',' read -ra entries <<< "$pmons"
    # Simple sort by position number
    for pos in $(seq 1 ${#entries[@]}); do
        for entry in "${entries[@]}"; do
            mon="${entry%%:*}"
            p="${entry##*:}"
            [[ "$p" == "$pos" ]] && ordered_mons+=("$mon")
        done
    done

    # Find max height for bottom alignment
    local max_h=0
    for m in "${ordered_mons[@]}"; do
        local h="${PREFERRED_RES[$m]#*x}"
        (( h > max_h )) && max_h=$h
    done

    # Build xrandr command
    local cmd="xrandr"
    local x_offset=0
    for m in "${ordered_mons[@]}"; do
        local res="${PREFERRED_RES[$m]}"
        local w="${res%x*}"
        local h="${res#*x}"
        local y_offset=$(( max_h - h ))
        cmd+=" --output $m --mode $res --pos ${x_offset}x${y_offset}"
        [[ "$m" == "$pprimary" ]] && cmd+=" --primary"
        x_offset=$(( x_offset + w ))
    done

    # Disable off monitors
    if [[ -n "$poff" ]]; then
        IFS=',' read -ra off_mons <<< "$poff"
        for om in "${off_mons[@]}"; do
            cmd+=" --output $om --off"
        done
    fi

    echo "$cmd"
    echo ""
    read -rp "Apply? [Y/n] " confirm
    if [[ "${confirm:-Y}" =~ ^[Yy]?$ ]]; then
        eval "$cmd"
        setxkbmap -layout us,ee -option grp:alt_shift_toggle
        ~/.config/polybar/launch.sh &
        echo "Done."
    else
        echo "Cancelled."
    fi
}

# --- Preset menu ---
echo "=== Monitor Arrangement ==="
echo ""
echo "Connected monitors:"
for i in "${!MONITORS[@]}"; do
    m="${MONITORS[$i]}"
    echo "  $m  (${PREFERRED_RES[$m]:-unknown})"
done
echo ""

if (( ${#AVAILABLE_PRESETS[@]} > 0 )); then
    echo "Presets:"
    for i in "${!AVAILABLE_PRESETS[@]}"; do
        IFS='|' read -r pname pmons pprimary poff <<< "${AVAILABLE_PRESETS[$i]}"
        # Build description
        IFS=',' read -ra entries <<< "$pmons"
        desc=""
        for entry in "${entries[@]}"; do
            mon="${entry%%:*}"
            [[ -n "$desc" ]] && desc+=" → "
            desc+="$mon (${PREFERRED_RES[$mon]})"
        done
        echo "  $((i+1)). $pname  [$desc]"
    done
    echo "  c. Custom (wizard)"
    echo ""
    read -rp "Choose preset or 'c' for custom: " pchoice

    if [[ "$pchoice" != "c" && "$pchoice" != "C" ]]; then
        pidx=$(( pchoice - 1 ))
        if (( pidx >= 0 && pidx < ${#AVAILABLE_PRESETS[@]} )); then
            apply_preset "${AVAILABLE_PRESETS[$pidx]}"
            exit 0
        fi
        echo "Invalid choice, falling through to wizard..."
    fi
    echo ""
fi

# --- Wizard fallback ---
echo "Which monitors to enable? (enter numbers separated by spaces, or 'a' for all)"
for i in "${!MONITORS[@]}"; do
    m="${MONITORS[$i]}"
    echo "  $((i+1)). $m  (preferred: ${PREFERRED_RES[$m]:-unknown})"
done
read -rp "> " selection

declare -a ENABLED=()
if [[ "$selection" == "a" || "$selection" == "A" ]]; then
    ENABLED=("${MONITORS[@]}")
else
    for n in $selection; do
        idx=$((n - 1))
        if (( idx >= 0 && idx < ${#MONITORS[@]} )); then
            ENABLED+=("${MONITORS[$idx]}")
        else
            echo "Invalid selection: $n"
            exit 1
        fi
    done
fi

if (( ${#ENABLED[@]} == 0 )); then
    echo "No monitors selected."
    exit 1
fi

# Use preferred resolution for each monitor
declare -A CHOSEN_RES=()
for m in "${ENABLED[@]}"; do
    CHOSEN_RES[$m]="${PREFERRED_RES[$m]}"
done

# Choose ordering left-to-right
echo ""
echo "Arrange monitors left to right."
echo "Current list:"
for i in "${!ENABLED[@]}"; do
    echo "  $((i+1)). ${ENABLED[$i]}  (${CHOSEN_RES[${ENABLED[$i]}]})"
done
echo ""
echo "Enter order as numbers left-to-right (e.g. '2 1 3'), or press Enter to keep current order:"
read -rp "> " order

declare -a ORDERED=()
if [[ -z "$order" ]]; then
    ORDERED=("${ENABLED[@]}")
else
    for n in $order; do
        idx=$((n - 1))
        ORDERED+=("${ENABLED[$idx]}")
    done
fi

# Choose primary
echo ""
echo "Which monitor should be primary?"
for i in "${!ORDERED[@]}"; do
    echo "  $((i+1)). ${ORDERED[$i]}  (${CHOSEN_RES[${ORDERED[$i]}]})"
done
read -rp "Choose [default: 1]: " pchoice
primary_idx=$(( ${pchoice:-1} - 1 ))
PRIMARY="${ORDERED[$primary_idx]}"

# Choose vertical alignment
max_h=0
for m in "${ORDERED[@]}"; do
    res="${CHOSEN_RES[$m]}"
    h="${res#*x}"
    (( h > max_h )) && max_h=$h
done

has_mixed_heights=false
for m in "${ORDERED[@]}"; do
    h="${CHOSEN_RES[$m]#*x}"
    [[ "$h" != "$max_h" ]] && has_mixed_heights=true
done

align="bottom"
if $has_mixed_heights; then
    echo ""
    echo "Monitors have different heights. Vertical alignment?"
    echo "  1. Bottom-aligned (recommended)"
    echo "  2. Top-aligned"
    read -rp "Choose [default: 1]: " achoice
    [[ "${achoice:-1}" == "2" ]] && align="top"
fi

# Build xrandr command
echo ""
echo "--- Applying layout ---"
cmd="xrandr"
x_offset=0
for m in "${ORDERED[@]}"; do
    res="${CHOSEN_RES[$m]}"
    w="${res%x*}"
    h="${res#*x}"

    if [[ "$align" == "bottom" ]]; then
        y_offset=$(( max_h - h ))
    else
        y_offset=0
    fi

    cmd+=" --output $m --mode $res --pos ${x_offset}x${y_offset}"
    [[ "$m" == "$PRIMARY" ]] && cmd+=" --primary"
    x_offset=$(( x_offset + w ))
done

# Disable monitors that are not enabled
for m in "${MONITORS[@]}"; do
    skip=false
    for e in "${ORDERED[@]}"; do
        [[ "$m" == "$e" ]] && skip=true
    done
    $skip || cmd+=" --output $m --off"
done

echo "$cmd"
echo ""
read -rp "Apply? [Y/n] " confirm
if [[ "${confirm:-Y}" =~ ^[Yy]?$ ]]; then
    eval "$cmd"
    setxkbmap -layout us,ee -option grp:alt_shift_toggle
    ~/.config/polybar/launch.sh &
    echo "Done."
else
    echo "Cancelled."
fi
