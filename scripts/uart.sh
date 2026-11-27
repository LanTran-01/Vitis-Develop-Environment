#!/usr/bin/env bash
# Serial terminal on the board UART.   Usage: uart.sh [PORT] [BAUD]
# Defaults come from [uart] in project.cfg. Does not need Vitis.
source "$(dirname "$0")/common.sh"
port="${1:-$(cfg_get uart port /dev/ttyUSB1)}"
baud="${2:-$(cfg_get uart baud 115200)}"
[[ -e "$port" ]] || die "$port not found. Available: $(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | tr '\n' ' ')"
[[ -r "$port" && -w "$port" ]] ||
    die "no permission on $port. Run: sudo usermod -aG dialout \$USER  (then log out and in)"
if command -v picocom >/dev/null; then
    echo "picocom $port @ $baud   (quit: Ctrl-A Ctrl-X)"
    exec picocom -b "$baud" "$port"
elif command -v minicom >/dev/null; then
    echo "minicom $port @ $baud   (quit: Ctrl-A X)"
    exec minicom -D "$port" -b "$baud"
elif command -v screen >/dev/null; then
    echo "screen $port @ $baud   (quit: Ctrl-A K)"
    exec screen "$port" "$baud"
else
    die "install a serial terminal: sudo apt install picocom"
fi
