#!/usr/bin/env bash
# Write build/boot/BOOT.BIN to the board as set in [flash] of project.cfg
# (QSPI/NAND/NOR/eMMC over JTAG, or copy to an SD card).
source "$(dirname "$0")/common.sh"
load_vitis
xsct "$TCL_DIR/flash.tcl"
