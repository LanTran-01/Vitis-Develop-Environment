@echo off
rem Delete everything generated (build\). Your hw\, src\ and config\ are kept.
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
if exist "%ROOT%\build" rmdir /s /q "%ROOT%\build"
echo Removed %ROOT%\build
