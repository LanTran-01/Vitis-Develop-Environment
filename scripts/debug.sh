#!/usr/bin/env bash
# Load an app over JTAG.   Usage: debug.sh [APP] [--run]
#   (default)  reset board, program PL, load APP, stop at main(), open the xsct debug shell
#   --run      same, but just run the app and exit (no debugger)
source "$(dirname "$0")/common.sh"
VDE_APP="" VDE_MODE=debug
for a in "$@"; do
    case "$a" in
        --run) VDE_MODE=run ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        -*) die "unknown option $a" ;;
        *) VDE_APP="$a" ;;
    esac
done
export VDE_APP VDE_MODE
load_vitis
if [[ $VDE_MODE == run ]]; then
    xsct "$TCL_DIR/debug.tcl"
else
    xsct -interactive "$TCL_DIR/debug.tcl"
fi
