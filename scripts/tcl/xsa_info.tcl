# xsa_info.tcl - list the processors (and UART-like IPs) in the XSA, to help fill project.cfg.
source [file join [file dirname [info script]] common.tcl]

main {
    set xsa [xsa_path]
    # open_hw_design extracts files next to the XSA, so work on a copy under build/.
    set tmp [file join $BUILD xsa_info]
    file delete -force $tmp
    file mkdir $tmp
    set copy [file join $tmp [file tail $xsa]]
    file copy $xsa $copy

    hsi::open_hw_design $copy
    puts "XSA: $xsa"
    puts "Processors (use as 'proc = ...' in a \[domain\] section):"
    foreach c [hsi::get_cells -hier -filter {IP_TYPE==PROCESSOR}] {
        set fam "?"
        catch {set fam [proc_family $c]}
        puts [format "  %-22s %s" $c $fam]
    }
    puts "Serial / debug IPs (candidates for bsp.stdout / bsp.stdin):"
    foreach c [hsi::get_cells -hier] {
        set ip [common::get_property IP_NAME $c]
        if {[string match -nocase *uart* $ip] || [string match -nocase *coresight* $ip] || $ip eq "mdm"} {
            puts [format "  %-22s %s" $c $ip]
        }
    }
    hsi::close_hw_design [hsi::current_hw_design]
    file delete -force $tmp
}
