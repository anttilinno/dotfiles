#!/bin/bash
# Switch foot terminal color theme.
# Themes live in ~/.config/foot/themes/*.ini — each contains a [colors] section.
# The active theme is copied to ~/.config/foot/colors.ini, which foot.ini includes.
# New foot windows pick up the change; existing windows are unaffected.

THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/foot/themes"
COLORS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/foot/colors.ini"
CURRENT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/foot/current-theme"

list_themes() {
    for f in "$THEMES_DIR"/*.ini; do
        basename "$f" .ini
    done
}

apply_theme() {
    local theme=$1
    local src="$THEMES_DIR/$theme.ini"

    if [[ ! -f "$src" ]]; then
        echo "foot-theme: '$theme' not found in $THEMES_DIR" >&2
        exit 1
    fi

    cp "$src" "$COLORS_FILE"
    echo "$theme" > "$CURRENT_FILE"
    notify-send "Foot Theme" "Switched to $theme" 2>/dev/null
    echo "foot theme: $theme"
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
