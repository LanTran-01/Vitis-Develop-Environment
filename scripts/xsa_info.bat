@echo off
rem List the processors and UARTs in the XSA, to help fill config\project.cfg.
setlocal
call "%~dp0common.bat" || exit /b 1
call xsct "%TCL_DIR%\xsa_info.tcl"
exit /b %errorlevel%
