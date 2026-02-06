@echo off
echo 🎖️ STRENGTHWAVE DRILL INSTRUCTOR AUDIO SETUP
echo.
echo This script will:
echo   1. Install required Python dependencies
echo   2. Generate ALL drill instructor audio files
echo.

if "%1"=="" (
    echo ❌ Please provide your OpenAI API key
    echo Usage: setup_and_generate_audio.bat YOUR_OPENAI_API_KEY
    echo Example: setup_and_generate_audio.bat sk-proj-...
    echo.
    echo 💡 Get your API key from: https://platform.openai.com/api-keys
    echo.
    pause
    exit /b 1
)

echo 📦 Installing Python dependencies...
pip install -r scripts/requirements.txt

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    echo Please make sure Python and pip are installed
    pause
    exit /b 1
)

echo.
echo 🎯 Generating drill instructor audio files...
echo.

python scripts/generate_countdown_audio.py %1

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ SUCCESS! All drill instructor audio files generated!
    echo.
    echo 🥊 Your StrengthWave boxing app is now ready with:
    echo    ✅ Commanding countdown: THREE! TWO! ONE!
    echo    ✅ High-energy combinations: ONE TWO SLIP TWO!
    echo    ✅ Motivational timing calls
    echo    ✅ Beast mode motivation phrases
    echo.
    echo 🚀 GET READY TO DOMINATE YOUR WORKOUT!
) else (
    echo.
    echo ❌ Error occurred during audio generation
    echo Please check your API key and internet connection
)

echo.
pause
