#!/usr/bin/env bash
# Terminal on the JTAG UART of an app's core.   Usage: jtag_uart.sh [APP]
# Arm needs bsp.stdout = ps7_coresight_comp_0 / psu_coresight_0 in the domain;
# MicroBlaze needs an MDM with JTAG UART enabled as stdout.
source "$(dirname "$0")/common.sh"
export VDE_APP="${1:-}"
load_vitis
xsct "$TCL_DIR/jtag_uart.tcl"
