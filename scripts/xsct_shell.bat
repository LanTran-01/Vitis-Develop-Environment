@echo off
rem Open an interactive xsct shell with the Vitis environment and the debug helpers loaded.
rem Type 'dbg_help' inside for the helper commands; any normal xsct command also works.
setlocal
call "%~dp0common.bat" || exit /b 1
set "VDE_MODE=shell"
call xsct -interactive "%TCL_DIR%\debug.tcl"
exit /b %errorlevel%
