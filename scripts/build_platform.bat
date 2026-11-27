@echo off
rem Build the platform (BSP domains + FSBL/PMUFW) from the XSA in hw\. Recreates build\workspace; src\ is not touched.
setlocal
call "%~dp0common.bat" || exit /b 1
call xsct "%TCL_DIR%\build_platform.tcl"
exit /b %errorlevel%
