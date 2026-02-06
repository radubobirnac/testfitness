@echo off
echo 🎖️ DRILL INSTRUCTOR AUDIO GENERATOR
echo.
echo This script will generate ALL essential boxing audio files using OpenAI TTS
echo.

if "%1"=="" (
    echo ❌ Please provide your OpenAI API key
    echo Usage: generate_boxing_audio.bat YOUR_OPENAI_API_KEY
    echo Example: generate_boxing_audio.bat sk-proj-...
    echo.
    pause
    exit /b 1
)

echo 🚀 Starting audio generation...
echo.

python scripts/generate_countdown_audio.py %1

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ SUCCESS! All drill instructor audio files generated!
    echo 🥊 Your boxing app is ready to DOMINATE!
) else (
    echo.
    echo ❌ Error occurred during audio generation
    echo Please check your API key and internet connection
)

echo.
pause
