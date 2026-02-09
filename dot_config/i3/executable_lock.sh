#!/bin/bash

i3lock \
    --clock \
    --indicator \
    --time-str="%H:%M" \
    --date-str="%a, %d %b" \
    --inside-color=00000080 \
    --time-color=ffffffff \
    --date-color=ffffffff \
    --image=/home/antti/.config/i3/lockscreen.jpg \
    --fill
