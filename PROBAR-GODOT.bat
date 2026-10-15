@echo off
cd /d "%~dp0"
echo === Prueba 1: con ciudad ===
godot\ZonaMuerta.console.exe --verbose
echo.
echo === Prueba 2: sin ciudad ===
godot\ZonaMuerta.console.exe -- nocity
pause
