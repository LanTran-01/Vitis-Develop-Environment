#!/usr/bin/env bash
# Build applications.   Usage: build_app.sh [APP] [--clean]
#   APP      build only this [app] (default: all apps in project.cfg)
#   --clean  recreate the app project (needed after changing defines/libs/template)
source "$(dirname "$0")/common.sh"
VDE_APP="" VDE_CLEAN=0
for a in "$@"; do
    case "$a" in
        --clean) VDE_CLEAN=1 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        -*) die "unknown option $a" ;;
        *) VDE_APP="$a" ;;
    esac
done
export VDE_APP VDE_CLEAN
load_vitis
xsct "$TCL_DIR/build_app.tcl"
