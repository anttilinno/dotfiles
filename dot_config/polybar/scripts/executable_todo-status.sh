#!/bin/bash

status=$(todo-calendar --status 2>/dev/null) || exit 0

daily=$(echo "$status" | jq -r '.daily')
monthly=$(echo "$status" | jq -r '.monthly')
yearly=$(echo "$status" | jq -r '.yearly')

if [ "$daily" = "0" ] && [ "$monthly" = "0" ] && [ "$yearly" = "0" ]; then
    exit 0
fi

colors_file=~/.config/polybar/colors.ini
alert=$(grep -oP 'alert\s*=\s*\K#[0-9a-fA-F]+' "$colors_file")
primary=$(grep -oP 'primary\s*=\s*\K#[0-9a-fA-F]+' "$colors_file")
secondary=$(grep -oP 'secondary\s*=\s*\K#[0-9a-fA-F]+' "$colors_file")

echo "%{F${alert}}${daily}%{F-} %{F${primary}}${monthly}%{F-} %{F${secondary}}${yearly}%{F-}"
