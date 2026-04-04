#!/bin/sh

choice=$(printf "Lock\nLog out\nSuspend\nReboot\nShutdown" | fuzzel --dmenu --prompt "Power: ")

case "$choice" in
    Lock) swaylock ;;
    "Log out") niri msg action quit --skip-confirmation ;;
    Suspend) systemctl suspend ;;
    Reboot) systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac
