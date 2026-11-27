# uart.tcl - serial terminal run by xsct (used on Windows, where picocom/minicom are not available).
source [file join [file dirname [info script]] common.tcl]
source [file join [file dirname [info script]] term.tcl]

main {
    set port [env_or VDE_PORT [cfg uart port]]
    set baud [env_or VDE_BAUD [cfg uart baud 115200]]
    if {$port eq ""} { die "no serial port: set port (or port_windows) in \[uart\]" }
    # Windows needs the \\.\ prefix for COM10 and above; it works for all COM ports.
    set dev $port
    if {[regexp -nocase {^COM\d+$} $port]} { set dev "\\\\.\\$port" }
    if {[catch {open $dev r+} chan]} { die "cannot open $port: $chan" }
    fconfigure $chan -mode $baud,n,8,1 -handshake none
    say "Serial $port @ $baud - type a line + Enter to send, '~.' + Enter to quit"
    term_attach $chan
}
exit 0
