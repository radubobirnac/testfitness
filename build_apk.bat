@echo off
echo ========================================
echo StrengthWave APK Builder
echo ========================================
echo.

echo [1/3] Cleaning previous builds...
flutter clean
echo.

echo [2/3] Getting dependencies...
flutter pub get
echo.

echo [3/3] Building release APK...
flutter build apk --release
echo.

echo ========================================
echo Build Complete!
echo ========================================
echo APK Location: build\app\outputs\flutter-apk\app-release.apk
echo.
pause
