:: win_update.bat
@echo off
:: Verifica permessi amministratore; se assenti, si rilancia elevato
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Richiesta permessi di amministratore...
    powershell -Command "Start-Process '%~f0' -Verb RunAs -Wait"
    exit /b
)

setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%win_update.ps1"
echo.
pause
