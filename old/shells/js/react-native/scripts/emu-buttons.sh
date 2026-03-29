#!/usr/bin/env bash
# Quick emulator button shortcuts via ADB

case "$1" in
    home|h)
        adb shell input keyevent KEYCODE_HOME
        echo "Home"
        ;;
    back|b)
        adb shell input keyevent KEYCODE_BACK
        echo "Back"
        ;;
    recent|r)
        adb shell input keyevent KEYCODE_APP_SWITCH
        echo "Recent Apps"
        ;;
    vol-up|vu)
        adb shell input keyevent KEYCODE_VOLUME_UP
        echo "Volume Up"
        ;;
    vol-down|vd)
        adb shell input keyevent KEYCODE_VOLUME_DOWN
        echo "Volume Down"
        ;;
    power|p)
        adb shell input keyevent KEYCODE_POWER
        echo "Power"
        ;;
    menu|m)
        adb shell input keyevent KEYCODE_MENU
        echo "Menu"
        ;;
    *)
        cat <<EOF
Usage: emu-buttons <command>

Commands:
  home, h         - Home button
  back, b         - Back button
  recent, r       - Recent apps
  vol-up, vu      - Volume up
  vol-down, vd    - Volume down
  power, p        - Power button
  menu, m         - Menu button

Examples:
  emu-buttons home
  emu-buttons b
  emu-buttons vu
EOF
        ;;
esac
