#!/usr/bin/env bash
# List the processors and UARTs in the XSA, to help fill config/project.cfg.
source "$(dirname "$0")/common.sh"
load_vitis
xsct "$TCL_DIR/xsa_info.tcl"
