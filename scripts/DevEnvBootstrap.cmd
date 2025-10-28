@echo off
setlocal
REM 优先使用 pwsh，其次 powershell
where pwsh >nul 2>&1
if %ERRORLEVEL%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
)