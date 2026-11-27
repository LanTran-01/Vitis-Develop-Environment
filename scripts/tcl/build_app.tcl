# build_app.tcl - create (if needed), sync sources from src/<app>/, and build each app.
source [file join [file dirname [info script]] common.tcl]

# All files under DIR as relative paths.
proc rel_files {dir} {
    set out {}
    foreach f [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $f]} {
            foreach g [rel_files $f] { lappend out [file join [file tail $f] $g] }
        } else {
            lappend out [file tail $f]
        }
    }
    return $out
}

proc remove_app {app} {
    say "Removing app project '$app' from the workspace"
    catch {app remove $app}
    catch {sysproj remove ${app}_system}
    file delete -force [file join $::WS $app] [file join $::WS ${app}_system]
}

proc create_app {app} {
    set sec "app $app"
    set template [cfg $sec template "Hello World"]
    say "Creating app '$app' (template: $template) on domain '[app_domain $app]'"
    app create -name $app -platform [platform_name] -domain [app_domain $app] \
        -template $template -lang [cfg $sec lang c]
    foreach sym [cfg $sec defines] { app config -name $app define-compiler-symbols $sym }
    foreach lib [cfg $sec libs]    { app config -name $app libraries $lib }
}

# Make the workspace copy of the sources match src/<app>/ exactly.
proc sync_sources {app src} {
    set dst  [file join $::WS $app src]
    set keep [rel_files $src]
    foreach f [rel_files $dst] {
        # Never drop the linker script, even if the user did not keep a copy.
        if {[lsearch -exact $keep $f] < 0 && $f ne "lscript.ld"} {
            file delete -force [file join $dst $f]
        }
    }
    set args [list -name $app -path $src]
    if {[file exists [file join $src lscript.ld]]} { lappend args -linker-script }
    importsources {*}$args
}

main {
    set p [platform_name]
    if {![file exists [file join $WS $p export $p $p.xpfm]]} {
        die "platform '$p' not built - run scripts/build_platform.sh first"
    }
    set clean [env_or VDE_CLEAN 0]
    setws $WS
    file mkdir $OUTDIR

    foreach app [selected_apps] {
        set build [string totitle [string tolower [cfg "app $app" build Debug]]]
        if {$build ni {Debug Release}} { die "\[app $app\] build must be Debug or Release" }
        set src [file join $ROOT src $app]
        set prj [file join $WS $app]

        if {$clean && [file exists $prj]} { remove_app $app }
        if {![file exists $prj]} {
            create_app $app
            if {![file isdirectory $src] || ![llength [glob -nocomplain -directory $src *]]} {
                say "Seeding src/$app/ from the template - edit your code there"
                file mkdir $src
                foreach f [glob -nocomplain -directory [file join $prj src] *] {
                    file copy -force $f $src
                }
            }
        }

        sync_sources $app $src
        app config -name $app build-config [string tolower $build]
        # Delete old outputs first so a failed build can never leave a stale ELF behind.
        set elf [file join $prj $build $app.elf]
        file delete -force $elf [app_elf $app]
        say "Building '$app' ($build)"
        app build -name $app

        if {![file exists $elf]} { die "build finished but $elf is missing - see the compiler output above" }
        file copy -force $elf [app_elf $app]
        say "OK: [app_elf $app]"
    }
}
