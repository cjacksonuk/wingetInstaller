@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "\\curric1\Install\App\winget\install-winget-20251028.ps1"
exit /b %errorlevel%