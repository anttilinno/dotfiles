#!/bin/bash
# Switch foot terminal color theme.
# Themes live in ~/.config/foot/themes/*.ini — each has a single [colors-light]
# or [colors-dark] section. The active theme is copied to ~/.config/foot/colors.ini
# (included by foot.ini), and initial-color-theme= in foot.ini is rewritten to
# match the theme's section — foot defaults to dark and ignores the mismatched
# section otherwise (no XDG color-scheme auto-detection).
# New foot windows pick up the change; existing windows are unaffected.

THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/foot/themes"
COLORS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/foot/colors.ini"
CURRENT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/foot/current-theme"
FOOT_INI="${XDG_CONFIG_HOME:-$HOME/.config}/foot/foot.ini"

list_themes() {
    for f in "$THEMES_DIR"/*.ini; do
        basename "$f" .ini
    done
}

detect_mode() {
    if grep -q '^\[colors-light\]' "$1"; then
        echo light
    else
        echo dark
    fi
}

set_initial_theme() {
    local mode=$1 tmp
    tmp=$(mktemp)
    if grep -q '^initial-color-theme=' "$FOOT_INI"; then
        sed "s/^initial-color-theme=.*/initial-color-theme=$mode/" "$FOOT_INI" > "$tmp"
    else
        awk -v mode="$mode" '
            /^\[main\]/ && !done { print; print "initial-color-theme=" mode; done=1; next }
            { print }
        ' "$FOOT_INI" > "$tmp"
    fi
    mv "$tmp" "$FOOT_INI"
}

apply_theme() {
    local theme=$1
    local src="$THEMES_DIR/$theme.ini"

    if [[ ! -f "$src" ]]; then
        echo "foot-theme: '$theme' not found in $THEMES_DIR" >&2
        exit 1
    fi

    local mode
    mode=$(detect_mode "$src")

    cp "$src" "$COLORS_FILE"
    set_initial_theme "$mode"
    echo "$theme" > "$CURRENT_FILE"
    notify-send "Foot Theme" "Switched to $theme ($mode)" 2>/dev/null
    echo "foot theme: $theme ($mode)"
}

current_theme() {
    [[ -f "$CURRENT_FILE" ]] && cat "$CURRENT_FILE" || echo "(none)"
}

case "${1:-}" in
    -l|--list)
        list_themes
        ;;
    -c|--current)
        current_theme
        ;;
    "")
        # Interactive picker — rofi if available, otherwise fzf, otherwise plain select
        themes=$(list_themes)
        if command -v rofi &>/dev/null; then
            chosen=$(echo "$themes" | rofi -dmenu -p "Foot theme" \
                -theme-str 'window {width: 280px;}')
        elif command -v fzf &>/dev/null; then
            chosen=$(echo "$themes" | fzf --prompt="Foot theme: ")
        else
            echo "Available themes:"
            select t in $themes; do chosen=$t; break; done
        fi
        [[ -n "$chosen" ]] && apply_theme "$chosen"
        ;;
    *)
        apply_theme "$1"
        ;;
esac
