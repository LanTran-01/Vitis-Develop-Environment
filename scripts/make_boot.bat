@echo off
rem Create build\boot\BOOT.BIN from the FSBL, bitstream and the apps in [boot] of project.cfg.
setlocal
call "%~dp0common.bat" || exit /b 1
call xsct "%TCL_DIR%\make_boot.tcl"
exit /b %errorlevel%
