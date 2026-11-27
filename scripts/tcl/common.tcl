# common.tcl - shared helpers for the Tcl scripts run inside xsct.
# Paths come from the environment exported by scripts/common.sh or scripts/common.bat.

set IS_WINDOWS [expr {$::tcl_platform(platform) eq "windows"}]
set ROOT    [file normalize $::env(VDE_ROOT)]
set CONFIG  [file normalize $::env(VDE_CONFIG)]
set BUILD   [file join $ROOT build]
set WS      [file join $BUILD workspace]   ;# Vitis workspace (disposable, regenerated)
set HWDIR   [file join $BUILD hw]          ;# extracted XSA contents (.bit, ps7_init.tcl, ...)
set OUTDIR  [file join $BUILD out]         ;# built ELFs, one per app
set BOOTDIR [file join $BUILD boot]        ;# boot.bif + BOOT.BIN

# In an interactive xsct session errors must not kill the shell.
set VDE_INTERACTIVE 0

proc say {msg} { puts "==> $msg"; flush stdout }
proc die {msg} {
    if {$::VDE_INTERACTIVE} { error $msg }
    puts stderr "ERROR: $msg"; flush stderr
    exit 1
}
proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}
# Run a script body; any Tcl error becomes one clear message and exit code 1.
proc main {body} {
    if {[catch {uplevel #0 $body} err]} { die $err }
}

# ---------------------------------------------------------------- config (INI)
proc cfg_load {path} {
    global CFG CFG_SECTIONS
    array unset CFG
    set CFG_SECTIONS {}
    if {![file exists $path]} { die "config not found: $path" }
    set f [open $path r]
    set sec ""
    set n 0
    while {[gets $f line] >= 0} {
        incr n
        set line [string trim $line]
        if {$line eq "" || [string match {[#;]*} $line]} continue
        if {[regexp {^\[(.+)\]$} $line -> sec]} {
            regsub -all {\s+} [string trim $sec] " " sec
            lappend CFG_SECTIONS $sec
            continue
        }
        if {![regexp {^([^=]+)=(.*)$} $line -> k v]} {
            close $f
            die "$path:$n: expected 'key = value', got: $line"
        }
        regsub {\s+#.*$} $v "" v
        set CFG($sec,[string trim $k]) [string trim $v]
    }
    close $f
}
# On Windows, KEY_windows (if set) overrides KEY, e.g. port_windows = COM3.
proc cfg {sec key {default ""}} {
    global CFG
    if {$::IS_WINDOWS && [info exists CFG($sec,${key}_windows)] && $CFG($sec,${key}_windows) ne ""} {
        return $CFG($sec,${key}_windows)
    }
    if {[info exists CFG($sec,$key)] && $CFG($sec,$key) ne ""} { return $CFG($sec,$key) }
    return $default
}
proc cfg_require {sec key} {
    set v [cfg $sec $key]
    if {$v eq ""} { die "missing '$key' in \[$sec\] of [file tail $::CONFIG]" }
    return $v
}
proc cfg_bool {sec key default} {
    set v [cfg $sec $key $default]
    if {![string is boolean -strict $v]} { die "\[$sec\] $key must be yes/no, got '$v'" }
    return [string is true -strict $v]
}
proc need_section {sec} {
    if {[lsearch -exact $::CFG_SECTIONS $sec] < 0} { die "config has no \[$sec\] section" }
}
# Names of all "[KIND NAME]" sections, e.g. cfg_names app -> {hello blinky}
proc cfg_names {kind} {
    set out {}
    foreach s $::CFG_SECTIONS {
        set parts [split $s " "]
        if {[llength $parts] == 2 && [lindex $parts 0] eq $kind} { lappend out [lindex $parts 1] }
    }
    return $out
}
# Keys of a section that start with PREFIX, e.g. cfg_keys "domain core0" bsp.
proc cfg_keys {sec prefix} {
    set out {}
    set n [string length "$sec,"]
    foreach name [array names ::CFG] {
        if {[string first "$sec," $name] != 0} continue
        set k [string range $name $n end]
        if {[string match "$prefix*" $k]} { lappend out $k }
    }
    return [lsort $out]
}

cfg_load $CONFIG

# Vitis workspaces and bootgen BIF files break on paths with spaces - fail early instead.
if {[string first " " $ROOT] >= 0} {
    die "the project path contains a space, which Vitis does not support: $ROOT"
}

# ---------------------------------------------------------------- project model
proc platform_name {} { cfg_require platform name }

proc xsa_path {} {
    set x [cfg platform xsa auto]
    if {$x eq "auto"} {
        set l [glob -nocomplain -directory [file join $::ROOT hw] *.xsa]
        if {[llength $l] == 0} { die "no .xsa file in hw/ - copy the XSA exported from Vivado there" }
        if {[llength $l] > 1}  { die "several .xsa files in hw/ - set 'xsa = hw/<file>.xsa' in \[platform\]" }
        return [file normalize [lindex $l 0]]
    }
    if {[file pathtype $x] eq "relative"} { set x [file join $::ROOT $x] }
    if {![file exists $x]} { die "XSA not found: $x" }
    return [file normalize $x]
}

proc app_names {} { cfg_names app }
proc app_domain {app} { need_section "app $app"; cfg_require "app $app" domain }
proc domain_proc {dom} { need_section "domain $dom"; cfg_require "domain $dom" proc }
proc app_proc {app} { domain_proc [app_domain $app] }
proc app_elf {app} { file join $::OUTDIR $app.elf }

# Apps selected by VDE_APP (from the command line) or all apps in the config.
proc selected_apps {} {
    set apps [env_or VDE_APP [app_names]]
    if {![llength $apps]} { die "config has no \[app NAME\] section" }
    foreach a $apps { need_section "app $a" }
    return $apps
}
# App used by debug / jtag_uart when none is given.
proc default_app {} {
    set a [env_or VDE_APP [cfg debug app [lindex [app_names] 0]]]
    if {$a eq ""} { die "no app given and none in \[debug\] app" }
    need_section "app $a"
    return $a
}

# Device family from the processor instance name.
proc proc_family {cpu} {
    switch -glob -- $cpu {
        ps7_cortexa9_*  { return zynq }
        psu_cortexa53_* { return zynqmp }
        psu_cortexr5_*  { return zynqmp }
        psv_*           { return versal }
        *microblaze*    { return microblaze }
        default         { die "unknown processor '$cpu'" }
    }
}
proc proc_index {cpu} {
    if {[regexp {_(\d+)$} $cpu -> n]} { return $n }
    return 0
}

# ---------------------------------------------------------------- build outputs
proc find_first {patterns} {
    foreach p $patterns {
        set l [lsort [glob -nocomplain $p]]
        if {[llength $l]} { return [lindex $l 0] }
    }
    return ""
}
proc fsbl_elf {} {
    set p [platform_name]
    set f [find_first [list \
        [file join $::WS $p export $p sw $p boot fsbl.elf] \
        [file join $::WS $p zynq_fsbl fsbl.elf] \
        [file join $::WS $p zynqmp_fsbl fsbl_a53.elf] \
        [file join $::WS $p zynqmp_fsbl *.elf]]]
    if {$f eq ""} { die "FSBL not found in the platform - run scripts/build_platform.sh first" }
    return $f
}
proc pmufw_elf {} {
    set p [platform_name]
    set f [find_first [list \
        [file join $::WS $p export $p sw $p boot pmufw.elf] \
        [file join $::WS $p zynqmp_pmufw pmufw.elf]]]
    if {$f eq ""} { die "PMU firmware not found in the platform - run scripts/build_platform.sh first" }
    return $f
}
# A file extracted from the XSA (e.g. ps7_init.tcl). Required.
proc hw_file {name} {
    set f [file join $::HWDIR $name]
    if {![file exists $f]} { die "$name not found in build/hw - run scripts/build_platform.sh first" }
    return $f
}
# The bitstream from the XSA, or "" if the XSA has none.
proc bitstream {} { find_first [list [file join $::HWDIR *.bit]] }

# ---------------------------------------------------------------- JTAG / hw_server
proc hw_server_url {} { cfg jtag hw_server TCP:127.0.0.1:3121 }

set VDE_CONNECTED 0
proc hw_connect {} {
    if {$::VDE_CONNECTED} return
    if {[cfg jtag hw_server] eq ""} {
        connect                         ;# starts a local hw_server if none is running
    } else {
        connect -url [cfg jtag hw_server]
    }
    set ::VDE_CONNECTED 1
}
# Select a target by name filter, restricted to [jtag] cable when set.
proc tgt {filter} {
    set cable [cfg jtag cable]
    if {$cable ne ""} { set filter "($filter) && jtag_cable_name =~ \"*$cable*\"" }
    targets -set -nocase -filter $filter
}
# Name filter for the debug target of a processor instance.
proc core_filter {cpu} {
    set n [proc_index $cpu]
    switch -glob -- $cpu {
        ps7_cortexa9_*  { return "name =~ \"*Cortex-A9*#$n\"" }
        psu_cortexa53_* { return "name =~ \"*Cortex-A53*#$n\"" }
        psu_cortexr5_*  { return "name =~ \"*Cortex-R5*#$n\"" }
        *microblaze*    { return "name =~ \"MicroBlaze #$n*\"" }
        default         { die "JTAG debug is not supported for '$cpu'" }
    }
}
