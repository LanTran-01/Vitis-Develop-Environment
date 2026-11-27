# build_platform.tcl - recreate the Vitis workspace + platform from the XSA and [domain] sections.
source [file join [file dirname [info script]] common.tcl]

proc extract_xsa {xsa dir} {
    # An XSA is a zip: .bit, ps7_init.tcl / psu_init.tcl, .hwh, ...
    # unzip (Linux), tar (built into Windows 10+, reads zip), python as a last resort.
    foreach cmd [list \
        [list unzip -o -q $xsa -d $dir] \
        [list tar -xf $xsa -C $dir] \
        [list python3 -m zipfile -e $xsa $dir] \
        [list python -m zipfile -e $xsa $dir]] {
        if {![catch {exec {*}$cmd}]} return
    }
    die "cannot extract the XSA - install 'unzip'"
}

main {
    set p   [platform_name]
    set xsa [xsa_path]
    set domains [cfg_names domain]
    if {![llength $domains]} { die "config has no \[domain NAME\] section" }

    # The workspace is fully generated: wipe it so no stale GUI/project state survives.
    say "Fresh workspace: $WS"
    file delete -force $WS $HWDIR $OUTDIR $BOOTDIR
    file mkdir $WS $HWDIR
    extract_xsa $xsa $HWDIR

    setws $WS
    say "Creating platform '$p' from [file tail $xsa]"
    platform create -name $p -hw $xsa

    foreach d $domains {
        set sec "domain $d"
        set cpu [cfg_require $sec proc]
        set os  [cfg $sec os standalone]
        set args [list -name $d -os $os -proc $cpu]
        if {[cfg $sec arch] ne ""} { lappend args -arch [cfg $sec arch] }
        say "Domain '$d': $os on $cpu"
        domain create {*}$args
        domain active $d
        foreach lib [cfg $sec libs] {
            say "  bsp setlib $lib"
            bsp setlib -name $lib
        }
        foreach key [cfg_keys $sec bsp.] {
            set param [string range $key 4 end]
            say "  bsp config $param [cfg $sec $key]"
            bsp config $param [cfg $sec $key]
        }
    }

    platform write
    say "Generating platform (BSPs + boot components). This takes a few minutes..."
    platform generate
    say "Platform ready: [file join $WS $p export $p $p.xpfm]"
    say "Next: scripts/build_app.sh"
}
