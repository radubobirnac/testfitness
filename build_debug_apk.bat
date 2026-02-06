@echo off
echo ========================================
echo StrengthWave Debug APK Builder
echo ========================================
echo.

echo [1/2] Getting dependencies...
flutter pub get
echo.

echo [2/2] Building debug APK...
flutter build apk --debug
echo.

echo ========================================
echo Debug Build Complete!
echo ========================================
echo APK Location: build\app\outputs\flutter-apk\app-debug.apk
echo.
pause
