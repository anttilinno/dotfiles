#!/bin/bash

options="󰌾  Lock\n󰍃  Logout\n󰒲  Suspend\n󰜉  Reboot\n󰐥  Shutdown"

selected=$(echo -e "$options" | rofi -dmenu \
    -no-custom \
    -disable-history \
    -theme-str 'window {width: 150px;}' \
    -theme-str 'listview {lines: 5; scrollbar: false;}' \
    -theme-str 'inputbar {enabled: false;}')

case $selected in
    "󰌾  Lock") ~/.config/i3/lock.sh ;;
    "󰍃  Logout") i3-msg exit ;;
    "󰒲  Suspend") systemctl suspend ;;
    "󰜉  Reboot") systemctl reboot ;;
    "󰐥  Shutdown") systemctl poweroff ;;
esac
