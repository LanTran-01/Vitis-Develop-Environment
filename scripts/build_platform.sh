#!/usr/bin/env bash
# Build the platform (BSP domains + FSBL/PMUFW) from the XSA in hw/.
# Recreates build/workspace from scratch every time; your sources in src/ are not touched.
source "$(dirname "$0")/common.sh"
load_vitis
xsct "$TCL_DIR/build_platform.tcl"
