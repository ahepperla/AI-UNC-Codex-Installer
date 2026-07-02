@echo off
setlocal
cd /d "%~dp0"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo Windows PowerShell was not found.
  echo This installer requires Windows PowerShell 5.1 or newer.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AI-UNC-Codex-Installer.ps1"
if errorlevel 1 (
  echo.
  echo The installer exited with an error.
  pause
)
