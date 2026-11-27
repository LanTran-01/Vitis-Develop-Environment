@echo off
rem Write build\boot\BOOT.BIN to the board as set in [flash] of project.cfg.
setlocal
call "%~dp0common.bat" || exit /b 1
call xsct "%TCL_DIR%\flash.tcl"
exit /b %errorlevel%
