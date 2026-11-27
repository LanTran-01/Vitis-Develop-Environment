# make_boot.tcl - write build/boot/boot.bif and run bootgen to produce BOOT.BIN.
source [file join [file dirname [info script]] common.tcl]

main {
    set apps [cfg boot apps [lindex [app_names] 0]]
    if {![llength $apps]} { die "no apps listed in \[boot\] apps" }

    set fam ""
    foreach app $apps {
        set f [proc_family [app_proc $app]]
        if {$fam eq ""} { set fam $f } elseif {$f ne $fam} { die "\[boot\] apps mix $fam and $f processors" }
        if {![file exists [app_elf $app]]} { die "[app_elf $app] missing - run scripts/build_app.sh" }
    }
    if {$fam ni {zynq zynqmp}} {
        die "BOOT.BIN is supported for Zynq-7000 and Zynq UltraScale+ only (this project is $fam)"
    }

    set bit ""
    if {[cfg_bool boot bitstream yes]} {
        set bit [bitstream]
        if {$bit eq ""} { die "the XSA has no bitstream - re-export with bitstream, or set \[boot\] bitstream = no" }
    }

    set lines {}
    if {$fam eq "zynq"} {
        lappend lines "\t\[bootloader\] [fsbl_elf]"
        if {$bit ne ""} { lappend lines "\t$bit" }
        foreach app $apps { lappend lines "\t[app_elf $app]" }
    } else {
        lappend lines "\t\[bootloader, destination_cpu = a53-0\] [fsbl_elf]"
        lappend lines "\t\[pmufw_image\] [pmufw_elf]"
        if {$bit ne ""} { lappend lines "\t\[destination_device = pl\] $bit" }
        foreach app $apps {
            set cpu [app_proc $app]
            set n   [proc_index $cpu]
            if {[string match psu_cortexr5_* $cpu]} {
                set attr "destination_cpu = r5-$n"
            } elseif {[cfg "domain [app_domain $app]" arch 64-bit] eq "32-bit"} {
                set attr "destination_cpu = a53-$n"
            } else {
                set attr "destination_cpu = a53-$n, exception_level = el-3"
            }
            lappend lines "\t\[$attr\] [app_elf $app]"
        }
    }

    file mkdir $BOOTDIR
    set bif  [file join $BOOTDIR boot.bif]
    set out  [file join $BOOTDIR BOOT.BIN]
    set fh [open $bif w]
    puts $fh "//arch = $fam; split = false; format = BIN"
    puts $fh "the_ROM_image:\n\{\n[join $lines \n]\n\}"
    close $fh
    say "BIF written: $bif"

    file delete -force $out
    say "bootgen -arch $fam"
    exec bootgen -image $bif -arch $fam -o $out -w on >@ stdout 2>@ stderr
    if {![file exists $out]} { die "bootgen did not produce $out" }
    say "OK: $out"
}
