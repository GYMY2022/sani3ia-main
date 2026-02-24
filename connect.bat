@echo off
echo ==============================
echo 🔗 Connecting to your Android device...
echo ==============================

REM شغّل السيرفر بتاع الـ ADB
adb start-server

REM استبدل العنوان ده بعنوان الموبايل الحقيقي بتاعك
adb connect 192.168.1.107:5555

echo ==============================
echo ✅ Connected successfully (if no error above)
echo ==============================

pause
