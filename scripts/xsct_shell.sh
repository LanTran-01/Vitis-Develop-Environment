#!/usr/bin/env bash
# Open an interactive xsct shell with the Vitis environment and the debug helpers loaded.
# Type 'dbg_help' inside for the helper commands; any normal xsct command also works.
source "$(dirname "$0")/common.sh"
load_vitis
VDE_MODE=shell exec xsct -interactive "$TCL_DIR/debug.tcl"
