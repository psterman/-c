@echo off
setlocal
chcp 65001 >nul 2>&1
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo error: missing .venv 1>&2
  exit /b 1
)
".venv\Scripts\python.exe" "%~dp0transcribe_cli.py" %*
exit /b %ERRORLEVEL%
