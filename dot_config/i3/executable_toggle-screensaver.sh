#!/bin/bash
if xset q | grep -q "DPMS is Enabled"; then
    xset s off -dpms
else
    xset s on +dpms
fi
polybar-msg action screensaver hook 0 2>/dev/null
