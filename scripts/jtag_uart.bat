@echo off
rem Terminal on the JTAG UART of an app's core.   Usage: jtag_uart.bat [APP]
rem Arm needs bsp.stdout = ps7_coresight_comp_0 / psu_coresight_0 in the domain. Quit: ~. and Enter.
setlocal
set "VDE_APP=%~1"
call "%~dp0common.bat" || exit /b 1
call xsct "%TCL_DIR%\jtag_uart.tcl"
exit /b %errorlevel%
