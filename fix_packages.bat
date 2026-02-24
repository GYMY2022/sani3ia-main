@echo off
echo 🛠️ بدء إصلاح حزم المشروع...

echo 📦 تنظيف المشروع...
flutter clean

echo 🗑️ حذف ملف القفل...
del pubspec.lock

echo 🔄 تحديث جميع الحزم...
flutter pub upgrade --major-versions

echo ✅ تم الإصلاح!
pause