@echo off
rem Load an app over JTAG.   Usage: debug.bat [APP] [--run]
rem   (default)  reset board, program PL, load APP, stop at main(), open the xsct debug shell
rem   --run      same, but just run the app and exit (no debugger)
setlocal
set "HERE=%~dp0"
set "VDE_APP="
set "VDE_MODE=debug"
:args
if "%~1"=="" goto run
if /i "%~1"=="--run" (
    set "VDE_MODE=run"
) else if "%~1"=="-h" (
    findstr /b "rem " "%HERE%debug.bat"
    exit /b 0
) else (
    set "VDE_APP=%~1"
)
shift
goto args
:run
call "%HERE%common.bat" || exit /b 1
if "%VDE_MODE%"=="run" (
    call xsct "%TCL_DIR%\debug.tcl"
) else (
    call xsct -interactive "%TCL_DIR%\debug.tcl"
)
exit /b %errorlevel%
