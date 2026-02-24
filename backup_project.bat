@echo off
cd /d %~dp0

echo ================================
echo      SANI3IA AUTO BACKUP
echo ================================

git add .

git diff --cached --quiet
if %errorlevel%==0 (
    echo No changes detected. Backup not needed.
    pause
    exit
)

git commit -m "Auto Backup %date% %time%"
git push origin main

echo.
echo Backup Completed Successfully!
pause