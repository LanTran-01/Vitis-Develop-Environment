# debug.tcl - JTAG load/run/debug helpers for xsct.
#   VDE_MODE=debug : load the app, stop at main(), stay in the xsct shell   (scripts/debug.sh)
#   VDE_MODE=run   : load the app, run it, exit                             (scripts/debug.sh --run)
#   VDE_MODE=shell : only define the helpers                                (scripts/xsct_shell)
source [file join [file dirname [info script]] common.tcl]

set DBG_APP ""

# Program the PL with BIT ("" = skip).
proc program_pl {bit} {
    if {$bit eq ""} return
    say "Programming PL: [file tail $bit]"
    # Select the FPGA device; if the name is not recognised, fpga picks the device itself.
    catch {tgt {name =~ "xc*" || name == "PL"}}
    fpga -file $bit
}

# Reset the board, program the PL, init the PS, download APP's ELF. Core is left halted at entry.
proc dbg_load {{app ""}} {
    if {$app eq ""} { set app [default_app] }
    set cpu [app_proc $app]
    set fam [proc_family $cpu]
    set elf [app_elf $app]
    if {![file exists $elf]} { die "$elf missing - run scripts/build_app.sh" }
    set bit ""
    if {[cfg_bool debug program_fpga yes]} { set bit [bitstream] }

    hw_connect
    say "Loading '$app' on $cpu ($fam)"
    switch -- $fam {
        zynq {
            tgt {name =~ "APU*"}
            rst -system
            after 3000
            program_pl $bit
            tgt {name =~ "APU*"}
            loadhw -hw [xsa_path] -mem-ranges [list {0x40000000 0xbfffffff}] -regs
            configparams force-mem-access 1
            uplevel #0 [list source [hw_file ps7_init.tcl]]
            ps7_init
            ps7_post_config
            tgt [core_filter $cpu]
            catch {stop}
            dow $elf
            configparams force-mem-access 0
        }
        zynqmp {
            tgt {name =~ "APU*"}
            rst -system
            after 3000
            program_pl $bit
            tgt {name =~ "APU*"}
            loadhw -hw [xsa_path] -mem-ranges [list {0x80000000 0xbfffffff} \
                {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}] -regs
            configparams force-mem-access 1
            uplevel #0 [list source [hw_file psu_init.tcl]]
            psu_init
            after 1000
            psu_ps_pl_isolation_removal
            after 1000
            psu_ps_pl_reset_config
            catch {psu_protection}
            tgt [core_filter $cpu]
            rst -processor
            dow $elf
            configparams force-mem-access 0
        }
        microblaze {
            if {$bit eq ""} { die "MicroBlaze needs the bitstream: set \[debug\] program_fpga = yes" }
            program_pl $bit
            tgt [core_filter $cpu]
            rst -processor
            dow $elf
        }
        default { die "JTAG load is not supported for $fam" }
    }
    set ::DBG_APP $app
    return
}

# Run until main() and stop there.
proc dbg_to_main {} {
    set id [bpadd -addr &main]
    if {[catch {con -block -timeout 30} err]} {
        puts "warning: did not reach main() within 30 s: $err"
    }
    bpremove $id
    return
}

# Re-download the ELF to the same core without resetting the board (after build_app.sh).
proc reload {} {
    if {$::DBG_APP eq ""} { die "nothing loaded yet - use dbg_load ?app?" }
    tgt [core_filter [app_proc $::DBG_APP]]
    catch {stop}
    dow [app_elf $::DBG_APP]
    dbg_to_main
}
# Full board reset + load + stop at main.
proc restart {{app ""}} {
    if {$app eq ""} { set app $::DBG_APP }
    dbg_load $app
    dbg_to_main
}

# ---- short gdb-style aliases for the xsct debug commands
proc b {loc} {
    if {[regexp {^(.+):(\d+)$} $loc -> file line]} { return [bpadd -file $file -line $line] }
    if {[string is integer -strict $loc]}         { return [bpadd -addr $loc] }
    return [bpadd -addr &$loc]
}
proc bl {}                  { bplist }
proc bd {id}                { if {$id eq "all"} { bpremove -all } else { bpremove $id } }
proc c {}                   { con }
proc s {}                   { stp }
proc n {}                   { nxt }
proc fin {}                 { stpout }
proc halt {}                { stop }
proc p {expr}               { print $expr }
proc l {}                   { locals }
proc regs {}                { rrd }
proc x {addr {count 1}}     { mrd $addr $count }

proc dbg_help {} {
    puts {
 Debug commands (short alias = xsct command)
   b main | b file.c:42 | b 0x100000   breakpoint      (bpadd)
   bl / bd ID / bd all                 list / delete   (bplist / bpremove)
   c                                   continue        (con)
   halt                                stop the core   (stop)
   s / n / fin                         step into / over / out (stp / nxt / stpout)
   p VAR   e.g. p count, p buf[3]      print variable  (print)
   l                                   local variables (locals)
   bt                                  backtrace
   regs                                registers       (rrd)
   x ADDR ?N?                          read N words    (mrd)
   mwr ADDR VALUE                      write memory
   reload                              re-download the ELF after build_app.sh
   restart ?app?                       reset board, load, stop at main
   dbg_load ?app?                      reset board and load (no run)
   targets                             list JTAG targets
   dbg_help                            this help;  exit = quit
}
}

switch -- [env_or VDE_MODE shell] {
    debug {
        set VDE_INTERACTIVE 1
        if {[catch {dbg_load; dbg_to_main} err]} {
            puts stderr "ERROR: $err"
            puts stderr "Fix the problem, then type: restart"
        } else {
            say "Stopped at main() of '$DBG_APP'"
        }
        dbg_help
    }
    run {
        main {
            dbg_load
            con
            say "'$DBG_APP' is running"
        }
        exit 0
    }
    shell {
        set VDE_INTERACTIVE 1
        say "xsct ready. Debug helpers loaded - type dbg_help"
    }
    default { die "unknown VDE_MODE" }
}
