# flash.tcl - put build/boot/BOOT.BIN on the board: program flash over JTAG, or copy to an SD card.
source [file join [file dirname [info script]] common.tcl]

main {
    set boot [file join $BOOTDIR BOOT.BIN]
    if {![file exists $boot]} { die "$boot missing - run scripts/make_boot.sh first" }

    switch -- [cfg flash method jtag] {
        sd {
            set dir [cfg_require flash sd_path]
            if {![file isdirectory $dir]} { die "SD card path '$dir' is not a mounted directory" }
            say "Copying BOOT.BIN to $dir"
            file copy -force $boot [file join $dir BOOT.BIN]
            catch {exec sync}
            say "OK - unmount the card, set the board to SD boot mode, and power-cycle"
        }
        jtag {
            # Make sure a local hw_server is up (xsct starts one on 'connect').
            if {[cfg jtag hw_server] eq ""} { catch {connect; disconnect} }
            set cmd [list program_flash -f $boot -offset [cfg flash offset 0] \
                -flash_type [cfg flash flash_type qspi-x4-single] -fsbl [fsbl_elf] \
                -cable type xilinx_tcf url [hw_server_url]]
            if {[cfg_bool flash verify yes]} { lappend cmd -verify }
            foreach a [cfg flash extra_args] { lappend cmd $a }
            say "Board must be in JTAG boot mode. Running:"
            puts "    [join $cmd]"
            exec {*}$cmd >@ stdout 2>@ stderr
            say "OK - set the board to QSPI/flash boot mode and power-cycle"
        }
        default { die "\[flash\] method must be 'jtag' or 'sd'" }
    }
}
