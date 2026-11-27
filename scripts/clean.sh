#!/usr/bin/env bash
# Delete everything generated (build/). Your hw/, src/ and config/ are kept.
source "$(dirname "$0")/common.sh"
rm -rf "$VDE_ROOT/build"
echo "Removed $VDE_ROOT/build"
