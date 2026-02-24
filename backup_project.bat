@echo off
cd /d "D:\sani3ia" 
git add .
git commit -m "Auto backup - %date% %time%"
git push
echo ==============================
echo ✅ Backup completed successfully!
pause