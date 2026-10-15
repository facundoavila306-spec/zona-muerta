@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set REPO=facundoavila306-spec/zona-muerta
set EL=https://github.com/electron/electron/releases/download/v33.2.0/electron-v33.2.0-win32-x64.zip
if not exist motor\ZonaMuerta.exe (
 echo [1/2] Primera vez: bajando el motor ^(115 MB, una sola vez^)...
 powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue';Invoke-WebRequest '%EL%' -OutFile motor.zip;Expand-Archive motor.zip -DestinationPath motor -Force;Remove-Item motor.zip"
 if exist motor\electron.exe ren motor\electron.exe ZonaMuerta.exe
 if exist motor\resources\default_app.asar del motor\resources\default_app.asar
)
echo [2/2] Buscando la ultima version del juego...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue';try{Invoke-WebRequest 'https://github.com/%REPO%/archive/refs/heads/main.zip' -OutFile juego.zip;if(Test-Path _tmp){Remove-Item _tmp -Recurse -Force};Expand-Archive juego.zip -DestinationPath _tmp -Force;Remove-Item juego.zip;exit 0}catch{exit 1}"
if errorlevel 1 (
 echo No se pudo actualizar, uso la version instalada.
) else (
 robocopy "_tmp\zona-muerta-main\app" "motor\resources\app" /E /NFL /NDL /NJH /NJS >nul
 rmdir /s /q _tmp
)
if not exist motor\resources\app\main.js (echo Falta el juego. Revisa tu internet y volve a ejecutar. & pause & exit /b 1)
start "" motor\ZonaMuerta.exe
