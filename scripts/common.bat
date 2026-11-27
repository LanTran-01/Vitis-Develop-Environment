@echo off
rem common.bat - called by every .bat script: paths + Vitis environment. Not meant to be run directly.
for %%I in ("%~dp0..") do set "VDE_ROOT=%%~fI"
if not defined VDE_CONFIG set "VDE_CONFIG=%VDE_ROOT%\config\project.cfg"
set "TCL_DIR=%VDE_ROOT%\scripts\tcl"

set "VITIS_PATH="
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%VDE_ROOT%\config\vitis.env") do (
    if /i "%%A"=="VITIS_PATH_WINDOWS" set "VITIS_PATH=%%~B"
)
if not defined VITIS_PATH (
    echo ERROR: set VITIS_PATH_WINDOWS in config\vitis.env 1>&2
    exit /b 1
)
if not exist "%VITIS_PATH%\settings64.bat" (
    echo ERROR: no settings64.bat in "%VITIS_PATH%" - edit VITIS_PATH_WINDOWS in config\vitis.env 1>&2
    exit /b 1
)
call "%VITIS_PATH%\settings64.bat" >nul
where xsct >nul 2>&1
if errorlevel 1 (
    echo ERROR: xsct not found after running "%VITIS_PATH%\settings64.bat" 1>&2
    exit /b 1
)
exit /b 0
