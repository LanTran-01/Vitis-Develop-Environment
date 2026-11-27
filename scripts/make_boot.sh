#!/usr/bin/env bash
# Create build/boot/BOOT.BIN from the FSBL, bitstream and the apps in [boot] of project.cfg.
source "$(dirname "$0")/common.sh"
load_vitis
xsct "$TCL_DIR/make_boot.tcl"
