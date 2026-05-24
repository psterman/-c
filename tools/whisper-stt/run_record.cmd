@echo off
setlocal
chcp 65001 >nul 2>&1
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo error: missing .venv\Scripts\python.exe 1>&2
  exit /b 1
)
set "ERRLOG=%~dp0..\..\Cache\wails_record_err.log"
if not exist "%~dp0..\..\Cache" mkdir "%~dp0..\..\Cache" >nul 2>&1
".venv\Scripts\python.exe" "%~dp0record_cli.py" %* 2>>"%ERRLOG%"
exit /b %ERRORLEVEL%
