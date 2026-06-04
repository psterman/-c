@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" (
  "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "%~dp0probe_hermes_test_conn.ahk"
) else if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" (
  "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" "%~dp0probe_hermes_test_conn.ahk"
) else (
  echo 未找到 AutoHotkey v2，请先安装。
  pause
)
