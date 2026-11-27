# jtag_uart.tcl - terminal on the JTAG UART (Arm DCC / MicroBlaze MDM) of the app's core.
source [file join [file dirname [info script]] common.tcl]
source [file join [file dirname [info script]] term.tcl]

main {
    set app [default_app]
    set cpu [app_proc $app]
    hw_connect
    tgt [core_filter $cpu]
    set port [jtagterminal -socket]
    set chan [socket 127.0.0.1 $port]
    say "JTAG UART of $cpu - type a line + Enter to send, '~.' + Enter to quit"
    term_attach $chan
}
exit 0
