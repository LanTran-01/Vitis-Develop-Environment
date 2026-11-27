@echo off
rem Serial terminal on the board UART.   Usage: uart.bat [COMx] [BAUD]
rem Defaults come from [uart] port_windows / baud in project.cfg. Quit: type ~. and Enter.
setlocal
set "VDE_PORT=%~1"
set "VDE_BAUD=%~2"
call "%~dp0common.bat" || exit /b 1
call xsct "%TCL_DIR%\uart.tcl"
exit /b %errorlevel%
