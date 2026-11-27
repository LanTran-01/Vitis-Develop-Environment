# term.tcl - minimal portable terminal: connects the console to a channel (serial port or socket).
# Bytes from the channel are printed as they arrive; typed lines are sent on Enter (with CR).
# Type '~.' + Enter to quit.

proc term_attach {chan} {
    fconfigure $chan -blocking 0 -buffering none -translation binary
    fconfigure stdin -blocking 0 -buffering line
    fconfigure stdout -buffering none
    fileevent $chan readable [list term_rx $chan]
    fileevent stdin readable [list term_tx $chan]
    vwait ::term_done
    catch {close $chan}
}
proc term_rx {chan} {
    set data [read $chan]
    if {$data ne ""} { puts -nonewline stdout $data }
    if {[eof $chan]} {
        puts "\n\[connection closed\]"
        set ::term_done 1
    }
}
proc term_tx {chan} {
    if {[gets stdin line] < 0} {
        if {[eof stdin]} { set ::term_done 1 }
        return
    }
    if {$line eq "~."} { set ::term_done 1; return }
    puts -nonewline $chan "$line\r"
    flush $chan
}
