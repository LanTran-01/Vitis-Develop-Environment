# common.sh - sourced by every script: paths, Vitis environment, config access.
set -euo pipefail

VDE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VDE_ROOT
export VDE_CONFIG="${VDE_CONFIG:-$VDE_ROOT/config/project.cfg}"
TCL_DIR="$VDE_ROOT/scripts/tcl"

die() { echo "ERROR: $*" >&2; exit 1; }

# Source config/vitis.env and the Vitis settings64.sh so xsct/bootgen/program_flash are on PATH.
load_vitis() {
    local env_file="$VDE_ROOT/config/vitis.env"
    [[ -f "$env_file" ]] || die "missing $env_file"
    # shellcheck source=/dev/null
    source "$env_file"
    [[ -n "${VITIS_PATH:-}" ]] || die "VITIS_PATH is not set in $env_file"
    [[ -f "$VITIS_PATH/settings64.sh" ]] ||
        die "no settings64.sh in VITIS_PATH=$VITIS_PATH (edit config/vitis.env)"
    # settings64.sh is not written for 'set -eu'
    set +eu
    # shellcheck source=/dev/null
    source "$VITIS_PATH/settings64.sh"
    set -eu
    if ! command -v xsct >/dev/null; then
        [[ "$(uname -m)" == x86_64 ]] ||
            die "xsct not found. Vitis 2022.2 runs only on x86_64 hosts; this machine is $(uname -m)."
        die "xsct not found after sourcing $VITIS_PATH/settings64.sh"
    fi
}

# cfg_get SECTION KEY [DEFAULT] - read one value from project.cfg (same rules as the Tcl parser).
cfg_get() {
    local v
    v=$(awk -v sec="$1" -v key="$2" '
        /^[ \t]*[#;]/ { next }
        /^[ \t]*\[/ {
            s = $0; gsub(/^[ \t]*\[[ \t]*|[ \t]*\][ \t]*$/, "", s); gsub(/[ \t]+/, " ", s)
            insec = (s == sec); next
        }
        insec {
            i = index($0, "="); if (!i) next
            k = substr($0, 1, i - 1); v = substr($0, i + 1)
            gsub(/^[ \t]+|[ \t]+$/, "", k)
            sub(/[ \t]+#.*$/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
            if (k == key) { print v; exit }
        }' "$VDE_CONFIG")
    echo "${v:-${3:-}}"
}
