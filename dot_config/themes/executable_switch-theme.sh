#!/bin/bash

THEME_DIR="$HOME/.config/themes"
CURRENT_THEME_FILE="$THEME_DIR/current"

apply_theme() {
    local theme=$1
    source "$THEME_DIR/gruvbox-$theme.sh"

    # Save current theme
    echo "$theme" > "$CURRENT_THEME_FILE"

    # Update Polybar
    cat > "$HOME/.config/polybar/colors.ini" << EOF
[colors]
background = $BG
foreground = $FG
primary = $GREEN
secondary = $AQUA
alert = $RED
EOF

    # Update i3
    cat > "$HOME/.config/i3/colors" << EOF
# Gruvbox $theme
set \$bg $BG
set \$bg1 $BG1
set \$bg2 $BG2
set \$fg $FG
set \$red $RED
set \$green $GREEN
set \$yellow $YELLOW
set \$blue $BLUE
set \$purple $PURPLE
set \$aqua $AQUA
set \$grey $GREY

# class                 border  backgr  text    indicator child_border
client.focused          \$green \$bg1    \$fg    \$aqua    \$green
client.focused_inactive \$bg2   \$bg1    \$grey  \$bg2     \$bg2
client.unfocused        \$bg1   \$bg     \$grey  \$bg1     \$bg1
client.urgent           \$red   \$red    \$bg    \$red     \$red
EOF

    # Update Rofi
    sed -i 's/@theme "gruvbox-[^"]*"/@theme "gruvbox-'"$theme"'"/' "$HOME/.config/rofi/config.rasi"

    # Update Wezterm
    if [ "$theme" = "dark" ]; then
        WEZTERM_SCHEME="Gruvbox Dark (Gogh)"
    else
        WEZTERM_SCHEME="Gruvbox Light"
    fi

    cat > "$HOME/.config/wezterm/colors.lua" << EOF
return "$WEZTERM_SCHEME"
EOF

    # Update GTK
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-application-prefer-dark-theme=$([ "$theme" = "dark" ] && echo "1" || echo "0")
EOF

    # GTK 4
    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-application-prefer-dark-theme=$([ "$theme" = "dark" ] && echo "1" || echo "0")
EOF

    # Apply GTK via gsettings if available
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null
        gsettings set org.gnome.desktop.interface color-scheme "prefer-$theme" 2>/dev/null
    fi

    # Set XDG/freedesktop color-scheme (0=default, 1=dark, 2=light)
    if [ "$theme" = "dark" ]; then
        XDG_COLOR_SCHEME=1
    else
        XDG_COLOR_SCHEME=2
    fi
    dconf write /org/freedesktop/appearance/color-scheme "$XDG_COLOR_SCHEME" 2>/dev/null

    # Update Zen Browser
    ZEN_PROFILE=$(find "$HOME/.zen" -maxdepth 1 -type d -name "*.Default*" 2>/dev/null | head -1)
    if [ -n "$ZEN_PROFILE" ]; then
        # Set Firefox/Zen dark mode preferences
        if [ "$theme" = "dark" ]; then
            ZEN_DARK_THEME=1
            ZEN_CONTENT_THEME=0
        else
            ZEN_DARK_THEME=0
            ZEN_CONTENT_THEME=2
        fi
        cat > "$ZEN_PROFILE/user.js" << EOF
user_pref("ui.systemUsesDarkTheme", $ZEN_DARK_THEME);
user_pref("browser.theme.content-theme", $ZEN_CONTENT_THEME);
user_pref("browser.theme.toolbar-theme", $ZEN_CONTENT_THEME);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
EOF

        mkdir -p "$ZEN_PROFILE/chrome"
        cat > "$ZEN_PROFILE/chrome/userChrome.css" << EOF
@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");

:root {
    --zen-colors-primary: $GREEN !important;
    --zen-primary-color: $GREEN !important;
    --toolbar-bgcolor: $BG !important;
    --lwt-accent-color: $BG !important;
    --lwt-toolbarbutton-icon-fill: $FG !important;
    --tab-selected-bgcolor: $BG1 !important;
    --urlbar-box-bgcolor: $BG1 !important;
    --urlbar-box-text-color: $FG !important;
    --sidebar-background-color: $BG !important;
    --sidebar-text-color: $FG !important;
}

/* Toolbar */
#nav-bar, #toolbar-menubar, #TabsToolbar, #PersonalToolbar {
    background-color: $BG !important;
}

/* URL bar */
#urlbar-background {
    background-color: $BG1 !important;
}

#urlbar-input {
    color: $FG !important;
}

/* Sidebar */
#sidebar-box {
    background-color: $BG !important;
}
EOF
    fi

    # Update btop
    if [ -f "$HOME/.config/btop/btop.conf" ]; then
        sed -i "s/^color_theme = .*/color_theme = \"gruvbox-$theme\"/" "$HOME/.config/btop/btop.conf"
    fi

    # Update lazygit
    mkdir -p "$HOME/.config/lazygit"
    cat > "$HOME/.config/lazygit/config.yml" << EOF
gui:
  theme:
    activeBorderColor:
      - "$GREEN"
      - bold
    inactiveBorderColor:
      - "$GREY"
    optionsTextColor:
      - "$AQUA"
    selectedLineBgColor:
      - "$BG2"
    selectedRangeBgColor:
      - "$BG1"
    cherryPickedCommitBgColor:
      - "$AQUA"
    cherryPickedCommitFgColor:
      - "$BG"
    markedBaseCommitBgColor:
      - "$YELLOW"
    markedBaseCommitFgColor:
      - "$BG"
    unstagedChangesColor:
      - "$RED"
    defaultFgColor:
      - "$FG"
EOF

    # Update yazi
    mkdir -p "$HOME/.config/yazi"
    cat > "$HOME/.config/yazi/theme.toml" << EOF
[manager]
cwd = { fg = "$AQUA" }
hovered = { fg = "$BG", bg = "$GREEN", bold = true }
preview_hovered = { underline = true }
find_keyword = { fg = "$YELLOW", bold = true }
find_position = { fg = "$PURPLE", bg = "reset", bold = true }
marker_selected = { fg = "$GREEN", bg = "$GREEN" }
marker_copied = { fg = "$YELLOW", bg = "$YELLOW" }
marker_cut = { fg = "$RED", bg = "$RED" }
tab_active = { fg = "$BG", bg = "$GREEN" }
tab_inactive = { fg = "$FG", bg = "$BG1" }
tab_width = 1
border_symbol = "│"
border_style = { fg = "$GREY" }
count_copied = { fg = "$BG", bg = "$YELLOW" }
count_cut = { fg = "$BG", bg = "$RED" }
count_selected = { fg = "$BG", bg = "$GREEN" }

[status]
separator_open = ""
separator_close = ""
separator_style = { fg = "$BG1", bg = "$BG1" }
mode_normal = { fg = "$BG", bg = "$GREEN", bold = true }
mode_select = { fg = "$BG", bg = "$YELLOW", bold = true }
mode_unset = { fg = "$BG", bg = "$PURPLE", bold = true }
progress_label = { fg = "$FG", bold = true }
progress_normal = { fg = "$BLUE", bg = "$BG1" }
progress_error = { fg = "$RED", bg = "$BG1" }
permissions_t = { fg = "$GREEN" }
permissions_r = { fg = "$YELLOW" }
permissions_w = { fg = "$RED" }
permissions_x = { fg = "$AQUA" }
permissions_s = { fg = "$GREY" }

[input]
border = { fg = "$GREEN" }
title = { fg = "$GREEN" }
value = { fg = "$FG" }
selected = { reversed = true }

[select]
border = { fg = "$GREEN" }
active = { fg = "$PURPLE" }
inactive = { fg = "$FG" }

[tasks]
border = { fg = "$GREEN" }
title = { fg = "$GREEN" }
hovered = { underline = true }

[which]
mask = { bg = "$BG1" }
cand = { fg = "$AQUA" }
rest = { fg = "$GREY" }
desc = { fg = "$FG" }
separator = "  "
separator_style = { fg = "$GREY" }

[help]
on = { fg = "$AQUA" }
run = { fg = "$PURPLE" }
desc = { fg = "$FG" }
hovered = { bg = "$BG2", bold = true }
footer = { fg = "$FG", bg = "$BG1" }

[filetype]
rules = [
  { mime = "image/*", fg = "$YELLOW" },
  { mime = "video/*", fg = "$PURPLE" },
  { mime = "audio/*", fg = "$PURPLE" },
  { mime = "application/zip", fg = "$RED" },
  { mime = "application/gzip", fg = "$RED" },
  { mime = "application/x-tar", fg = "$RED" },
  { mime = "application/x-bzip*", fg = "$RED" },
  { mime = "application/x-xz", fg = "$RED" },
  { mime = "application/x-7z-compressed", fg = "$RED" },
  { mime = "application/x-rar", fg = "$RED" },
  { name = "*.json", fg = "$YELLOW" },
  { name = "*.md", fg = "$YELLOW" },
  { name = "*.rs", fg = "$ORANGE" },
  { name = "*.go", fg = "$AQUA" },
  { name = "*.py", fg = "$BLUE" },
  { name = "*.js", fg = "$YELLOW" },
  { name = "*.ts", fg = "$BLUE" },
  { name = "*.lua", fg = "$BLUE" },
  { name = "*.sh", fg = "$GREEN" },
  { name = "*", fg = "$FG" },
  { name = "*/", fg = "$BLUE" },
]
EOF

    # Update lazydocker
    mkdir -p "$HOME/.config/lazydocker"
    cat > "$HOME/.config/lazydocker/config.yml" << EOF
gui:
  theme:
    activeBorderColor:
      - "$GREEN"
      - bold
    inactiveBorderColor:
      - "$GREY"
    optionsTextColor:
      - "$AQUA"
    selectedLineBgColor:
      - "$BG2"
    selectedRangeBgColor:
      - "$BG1"
EOF

    # Reload i3 (this also relaunches polybar via exec_always)
    i3-msg reload &>/dev/null

    notify-send "Theme Switched" "Gruvbox $theme applied" 2>/dev/null
}

# If called with argument, apply directly
if [ -n "$1" ]; then
    apply_theme "$1"
    exit 0
fi

# Show Rofi menu
chosen=$(printf "Dark\nLight" | rofi -dmenu -p "Theme" -theme-str 'window {width: 200px;}')

case "$chosen" in
    "Dark") apply_theme "dark" ;;
    "Light") apply_theme "light" ;;
esac
