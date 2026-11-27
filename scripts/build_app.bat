@echo off
rem Build applications.   Usage: build_app.bat [APP] [--clean]
rem   APP      build only this [app] (default: all apps in project.cfg)
rem   --clean  recreate the app project (needed after changing defines/libs/template)
setlocal
set "HERE=%~dp0"
set "VDE_APP="
set "VDE_CLEAN=0"
:args
if "%~1"=="" goto run
if /i "%~1"=="--clean" (
    set "VDE_CLEAN=1"
) else if "%~1"=="-h" (
    findstr /b "rem " "%HERE%build_app.bat"
    exit /b 0
) else (
    set "VDE_APP=%~1"
)
shift
goto args
:run
call "%HERE%common.bat" || exit /b 1
call xsct "%TCL_DIR%\build_app.tcl"
exit /b %errorlevel%
