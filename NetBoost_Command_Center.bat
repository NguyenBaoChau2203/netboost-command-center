@echo off
setlocal EnableExtensions
chcp 65001 >nul

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :Elevated
) else (
    echo [INFO] Dang yeu cau quyen Administrator...
    if "%~1"=="" (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b 0
)

:Elevated
set "SCRIPT=%~dp0src\powershell\NetBoost_Command_Center.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Khong tim thay file PowerShell:
    echo %SCRIPT%
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %errorlevel%
