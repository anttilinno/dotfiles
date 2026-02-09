#!/bin/bash
# Interactive monitor arrangement wizard

set -euo pipefail

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

echo "=== Monitor Arrangement Wizard ==="
echo ""
echo "Connected monitors:"
for i in "${!MONITORS[@]}"; do
    m="${MONITORS[$i]}"
    echo "  $((i+1)). $m  (preferred: ${PREFERRED_RES[$m]:-unknown})"
done
echo ""

# Select which monitors to enable
echo "Which monitors to enable? (enter numbers separated by spaces, or 'a' for all)"
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
