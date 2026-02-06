@echo off
echo ========================================
echo StrengthWave Release APK Builder
echo ========================================
echo.

echo [1/3] Cleaning previous builds...
flutter clean
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter clean failed!
    echo.
    pause
    exit /b 1
)
echo Clean completed successfully.
echo.

echo [2/3] Getting dependencies...
flutter pub get
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter pub get failed!
    echo Check your internet connection and pubspec.yaml
    echo.
    pause
    exit /b 1
)
echo Dependencies retrieved successfully.
echo.

echo [3/3] Building release APK...
flutter build apk --release
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter build failed!
    echo Check the error messages above for details.
    echo Common issues:
    echo - Missing Android SDK
    echo - Gradle issues
    echo - Code compilation errors
    echo.
    pause
    exit /b 1
)
echo.

echo ========================================
echo Release Build Complete!
echo ========================================
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo File Size:
    for %%A in (build\app\outputs\flutter-apk\app-release.apk) do echo %%~zA bytes
    echo.
    echo ✅ Ready for Google Drive upload and testing!
) else (
    echo ❌ ERROR: APK file not found!
    echo The build may have failed silently.
)
echo.
echo Press any key to close this window...
pause >nul
