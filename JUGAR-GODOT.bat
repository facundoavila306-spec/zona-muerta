@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set RAW=https://github.com/facundoavila306-spec/zona-muerta/raw/main/godot
if not exist godot mkdir godot
echo Buscando la ultima version (Godot)...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue';try{Invoke-WebRequest '%RAW%/version.txt' -OutFile godot\version.new;exit 0}catch{exit 1}"
if errorlevel 1 (
 echo No se pudo consultar internet, uso la version instalada.
) else (
 fc /b godot\version.new godot\version.txt >nul 2>&1
 if errorlevel 1 (
  echo Bajando el juego...
  powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue';Invoke-WebRequest '%RAW%/ZonaMuerta.pck' -OutFile godot\ZonaMuerta.pck"
  copy /y godot\version.new godot\version.txt >nul
 )
 powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue';try{Invoke-WebRequest '%RAW%/ZonaMuerta.console.exe' -OutFile godot\ZonaMuerta.console.exe}catch{}"
 if not exist godot\ZonaMuerta.exe (
  echo Bajando el motor ^(84 MB, una sola vez^)...
  powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue';Invoke-WebRequest '%RAW%/ZonaMuerta.exe' -OutFile godot\ZonaMuerta.exe"
 )
)
if not exist godot\ZonaMuerta.exe (echo Falta el juego. Revisa tu internet y volve a ejecutar. & pause & exit /b 1)
start "" godot\ZonaMuerta.exe
